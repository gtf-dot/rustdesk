#!/usr/bin/env bash
# Shared preparation for build_linux.sh and build_mac.sh. Source it, do not run it.
#
# Assumes the toolchain is installed (rustup, Flutter, vcpkg, LLVM, system libs)
# and makes the checkout ready to build: submodules, vcpkg ports, the Flutter
# patch CI applies, pub packages and the flutter_rust_bridge glue.
# RENDEZVOUS_SERVERS and RS_PUB_KEY are exported from ./.env (see .env.example)
# so that option_env!() in hbb_common compiles them into the binary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

FLUTTER_VERSION="3.24.5"
FLUTTER_RUST_BRIDGE_VERSION="1.80.1"
CARGO_EXPAND_VERSION="1.0.95"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:$HOME/flutter/bin:$PATH"
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found. $2" >&2; exit 1; }
}
need cargo "Install Rust 1.75 with rustup: https://rustup.rs"
need flutter "Install Flutter $FLUTTER_VERSION and put flutter/bin on PATH"
need python3 "Install Python 3"
need git "Install git"
[ -x "$VCPKG_ROOT/vcpkg" ] || {
    echo "error: vcpkg not found at \$VCPKG_ROOT=$VCPKG_ROOT (clone microsoft/vcpkg at commit 120deac3 and bootstrap it)" >&2
    exit 1
}

echo "==> submodules"
git submodule update --init --recursive

# Server and key are compiled in via option_env!() in libs/hbb_common/src/config.rs.
# Export them from .env, exactly like CI exports its secrets. Variables already set
# in the environment take precedence over the file.
if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"
        case "$line" in ''|'#'*) continue ;; esac
        line="${line#export }"
        key="${line%%=*}"; value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        case "$key" in RENDEZVOUS_SERVERS|RS_PUB_KEY) ;; *) continue ;; esac
        [ -n "${!key:-}" ] && continue
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
        esac
        [ -n "$value" ] && export "$key=$value"
    done < .env
fi
if [ -z "${RENDEZVOUS_SERVERS:-}" ] || [ -z "${RS_PUB_KEY:-}" ]; then
    echo "warning: RENDEZVOUS_SERVERS / RS_PUB_KEY not set; the build will default to the public rustdesk server." >&2
    echo "         cp .env.example .env and fill them in." >&2
else
    echo "==> server: $RENDEZVOUS_SERVERS"
fi

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  VCPKG_TRIPLET=x64-linux ;;
    Linux-aarch64) VCPKG_TRIPLET=arm64-linux ;;
    Darwin-arm64)  VCPKG_TRIPLET=arm64-osx ;;
    Darwin-x86_64) VCPKG_TRIPLET=x64-osx ;;
    *) echo "error: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
export VCPKG_DEFAULT_HOST_TRIPLET="$VCPKG_TRIPLET"

if [ ! -f "$VCPKG_ROOT/installed/$VCPKG_TRIPLET/lib/libvpx.a" ]; then
    echo "==> vcpkg install ($VCPKG_TRIPLET), this builds ffmpeg and takes a while"
    "$VCPKG_ROOT/vcpkg" install --triplet "$VCPKG_TRIPLET" --x-install-root="$VCPKG_ROOT/installed"
fi

echo "==> rust helper tools"
rustup component add rustfmt >/dev/null 2>&1 || true
command -v cargo-expand >/dev/null 2>&1 ||
    cargo install cargo-expand --version "$CARGO_EXPAND_VERSION" --locked
command -v flutter_rust_bridge_codegen >/dev/null 2>&1 ||
    cargo install flutter_rust_bridge_codegen --version "$FLUTTER_RUST_BRIDGE_VERSION" --features uuid --locked

# CI patches Flutter 3.24.5's DropdownMenu; apply once, idempotently.
FLUTTER_DIR="$(dirname "$(dirname "$(command -v flutter)")")"
FLUTTER_PATCH="$ROOT/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
if flutter --version 2>/dev/null | head -1 | grep -q "Flutter $FLUTTER_VERSION" &&
   git -C "$FLUTTER_DIR" apply --check "$FLUTTER_PATCH" 2>/dev/null; then
    echo "==> patching Flutter $FLUTTER_VERSION"
    git -C "$FLUTTER_DIR" apply "$FLUTTER_PATCH"
fi

echo "==> flutter pub get"
(cd flutter && flutter pub get)

# ffigen only probes LLVM 9-14 by default; point it at what is installed.
LLVM_ARGS=()
case "$(uname -s)" in
    Linux)
        llvm_dir="$(ls -d /usr/lib/llvm-* 2>/dev/null | sort -V | tail -1 || true)"
        [ -n "$llvm_dir" ] && [ -f "$llvm_dir/lib/libclang.so" ] && LLVM_ARGS=(--llvm-path "$llvm_dir")
        ;;
    Darwin)
        for d in /opt/homebrew/opt/llvm@15 /opt/homebrew/opt/llvm /usr/local/opt/llvm; do
            [ -d "$d" ] && { LLVM_ARGS=(--llvm-path "$d"); break; }
        done
        ;;
esac

if [ ! -f src/bridge_generated.rs ] || [ src/flutter_ffi.rs -nt src/bridge_generated.rs ]; then
    echo "==> generating flutter_rust_bridge glue"
    flutter_rust_bridge_codegen ${LLVM_ARGS[@]+"${LLVM_ARGS[@]}"} \
        --rust-input ./src/flutter_ffi.rs \
        --dart-output ./flutter/lib/generated_bridge.dart \
        --c-output ./flutter/macos/Runner/bridge_generated.h
    cp ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h
fi

#!/bin/bash
# macOS (Apple Silicon) build, mirroring .github/workflows/flutter-build.yml "build-for-macOS" (aarch64 job).
# One-time prereqs (already installed on this Mac):
#   full Xcode (needed by `flutter build macos` and by the cidre crate behind --screencapturekit),
#   rustup 1.81, fvm flutter 3.24.5 (+ .github/patches dropdown patch), brew llvm@15 create-dmg pkg-config
#   cmake ninja cocoapods, NASM 2.16.x in ~/.local/bin, vcpkg at $VCPKG_ROOT with `vcpkg install` done,
#   bridge files generated per .github/workflows/bridge.yml (flutter_rust_bridge_codegen 1.80.1).
set -e
cd "$(dirname "$0")"

export PATH="$HOME/fvm/versions/3.24.5/bin:$HOME/.cargo/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
# bindgen 0.65 (libs/scrap) emits opaque structs with libclang >= 16; use LLVM 15 like CI does.
export LIBCLANG_PATH="/opt/homebrew/opt/llvm@15/lib"
# macOS 26 SDK TargetConditionals.h #errors under clang 15 because the unknown "kernelkit" environment
# matches the bare darwin triple; neutralise the check (coreaudio-sys bindgen).
export BINDGEN_EXTRA_CLANG_ARGS="-D__is_target_environment(x)=0"

# CI raises the minimum macOS to 12.3 on arm64 (required by --screencapturekit).
MIN_MACOS_VERSION="12.3"
sed -i '' -e "s/MACOSX_DEPLOYMENT_TARGET\=[0-9]*.[0-9]*/MACOSX_DEPLOYMENT_TARGET=${MIN_MACOS_VERSION}/" build.py
sed -i '' -e "s/platform :osx, '.*'/platform :osx, '${MIN_MACOS_VERSION}'/" flutter/macos/Podfile
sed -i '' -e "s/osx_minimum_system_version = \"[0-9]*.[0-9]*\"/osx_minimum_system_version = \"${MIN_MACOS_VERSION}\"/" Cargo.toml
sed -i '' -e "s/MACOSX_DEPLOYMENT_TARGET = [0-9]*.[0-9]*;/MACOSX_DEPLOYMENT_TARGET = ${MIN_MACOS_VERSION};/" flutter/macos/Runner.xcodeproj/project.pbxproj

# submodules, vcpkg ports, Flutter patch, pub get and bridge glue (shared with build_linux.sh)
. ./build_prepare.sh

python3 build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit "$@"

# Xcode leaves the main binary ad-hoc signed while FlutterMacOS.framework keeps its upstream signature,
# and dyld refuses the mismatch at launch ("different Team IDs"). Re-sign the whole bundle ad-hoc, as CI's
# `codesign --deep` step does with a real identity.
APP=$(ls -d flutter/build/macos/Build/Products/Release/*.app | head -1)
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built and ad-hoc signed: $APP"

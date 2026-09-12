#!/usr/bin/env bash
# Linux (x86_64 / aarch64) release build, mirroring .github/workflows/flutter-build-linux.yml.
# No parameters. Server and key are read from ./.env (see .env.example).
#
# One-time prereqs: Rust 1.75 (rustup), Flutter 3.24.5 at ~/flutter, vcpkg at ~/vcpkg
# (or $VCPKG_ROOT), and the apt packages:
#   build-essential clang cmake ninja-build nasm yasm pkg-config libclang-dev llvm-dev
#   libgtk-3-dev libayatana-appindicator3-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
#   libasound2-dev libpulse-dev libpam0g-dev libva-dev libssl-dev libxdo-dev libxfixes-dev
#   libxcb-randr0-dev libxcb-shape0-dev libxcb-xfixes0-dev
set -euo pipefail
cd "$(dirname "$0")"

. ./build_prepare.sh

echo "==> building (cargo + flutter + deb)"
python3 build.py --flutter --hwcodec --unix-file-copy-paste

echo
echo "Built:"
echo "  app bundle: flutter/build/linux/x64/release/bundle/"
ls -1 ./*.deb 2>/dev/null | sed 's/^/  package:    /' || true

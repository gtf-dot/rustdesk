#!/bin/bash
export PATH="/home/german/fvm/versions/3.24.5/bin:$PATH"
export PKG_CONFIG_PATH="/home/german/.local/lib/pkgconfig"
python3 build_lin.py --flutter "$@"
./flutter/build/linux/x64/release/bundle/rustdesk

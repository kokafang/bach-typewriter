#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$ROOT/.build-local"
MODULE_CACHE_DIR="$CACHE_DIR/module-cache"
SWIFTPM_CACHE_DIR="$CACHE_DIR/swiftpm-cache"

mkdir -p "$MODULE_CACHE_DIR" "$SWIFTPM_CACHE_DIR"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
export SWIFTPM_CUSTOM_CACHE="$SWIFTPM_CACHE_DIR"
export SWIFTPM_DISABLE_SANDBOX=1
export HOME="$ROOT/.home"

mkdir -p "$HOME/Library/Caches/org.swift.swiftpm" "$HOME/Library/org.swift.swiftpm/configuration" "$HOME/Library/org.swift.swiftpm/security"

cd "$ROOT"
swift run --disable-sandbox bach-typewriter-swift

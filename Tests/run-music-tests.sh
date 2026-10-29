#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
swiftc -o "$BUILD_DIR/music-tests" "$ROOT/Sela/Music/MusicService.swift" "$ROOT/Tests/MusicServiceTests.swift"
"$BUILD_DIR/music-tests"

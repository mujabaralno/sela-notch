#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
swiftc "$ROOT/Sela/Shelf/ShelfService.swift" "$ROOT/Tests/ShelfServiceTests.swift" -o "$BUILD_DIR/shelf-tests"
"$BUILD_DIR/shelf-tests"
swiftc "$ROOT/Sela/Shelf/ShelfService.swift" "$ROOT/Sela/Shelf/ShelfDropContainer.swift" "$ROOT/Tests/ShelfDropTests.swift" -o "$BUILD_DIR/drop-tests"
"$BUILD_DIR/drop-tests"

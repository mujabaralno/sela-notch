#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

swiftc -o "$BUILD_DIR/battery-tests" \
  "$ROOT/Sela/BatteryAlertPolicy.swift" \
  "$ROOT/Tests/BatteryAlertPolicyTests.swift"

"$BUILD_DIR/battery-tests"

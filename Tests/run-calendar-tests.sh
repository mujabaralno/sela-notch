#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

swiftc -o "$BUILD_DIR/calendar-tests" \
  "$ROOT/Sela/Calendar/CalendarModels.swift" \
  "$ROOT/Sela/Calendar/CalendarService.swift" \
  "$ROOT/Tests/CalendarAgendaTests.swift"

"$BUILD_DIR/calendar-tests"

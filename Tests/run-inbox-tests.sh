#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

swiftc -o "$BUILD_DIR/inbox-tests" \
  "$ROOT/Sela/Inbox/InboxModels.swift" \
  "$ROOT/Sela/Inbox/InboxService.swift" \
  "$ROOT/Sela/Inbox/AccessibilityBannerObserver.swift" \
  "$ROOT/Tests/InboxServiceTests.swift"

"$BUILD_DIR/inbox-tests"

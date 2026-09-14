#!/usr/bin/env bash
# Runs what CI runs: format check, lint, build and test for every package.
# Usage: ./Tools/ci.sh            (from the repo root)
#
# Which `swift`: set SWIFT to a specific binary to override. On a Mac with only the
# Command Line Tools, Apple's `swift test` cannot load the Testing framework, so this
# script falls back to a swift.org toolchain in ~/Library/Developer/Toolchains when
# one is installed. With full Xcode, plain `swift` is fine.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

pick_swift() {
    if [[ -n "${SWIFT:-}" ]]; then
        echo "$SWIFT"
        return
    fi
    if xcode-select -p 2>/dev/null | grep -q 'Xcode.app'; then
        echo "swift"
        return
    fi
    local latest="$HOME/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift"
    if [[ -x "$latest" ]]; then
        echo "$latest"
        return
    fi
    echo "swift"
}

SWIFT_BIN="$(pick_swift)"
echo "▸ using: $("$SWIFT_BIN" -version 2>&1 | head -1)"

echo "▸ swift-format lint"
xcrun swift-format lint --strict --recursive Packages

if command -v swiftlint >/dev/null 2>&1; then
    echo "▸ swiftlint"
    swiftlint --strict --quiet
else
    echo "▸ swiftlint not installed locally; skipping (CI runs it)"
fi

for pkg in Packages/StudyBotCore Packages/StudyBotKit; do
    echo "▸ swift build  ($pkg)"
    (cd "$pkg" && "$SWIFT_BIN" build --quiet)
    echo "▸ swift test   ($pkg)"
    (cd "$pkg" && "$SWIFT_BIN" test --quiet)
done

echo "✓ all green"

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
xcrun swift-format lint --strict --recursive Packages Apps Server/Sources Server/Tests

if command -v swiftlint >/dev/null 2>&1; then
    echo "▸ swiftlint"
    # Without Xcode, SwiftLint needs to be told where SourceKit lives.
    if [[ "$SWIFT_BIN" == *".xctoolchain/"* ]]; then
        export TOOLCHAIN_DIR="${SWIFT_BIN%/usr/bin/swift}"
    fi
    swiftlint --strict --quiet
else
    echo "▸ swiftlint not installed locally; skipping (CI runs it)"
fi

for pkg in Packages/StudyBotCore Packages/StudyBotKit Packages/StudyBotUI Server; do
    echo "▸ swift build  ($pkg)"
    (cd "$pkg" && "$SWIFT_BIN" build --quiet)
    echo "▸ swift test   ($pkg)"
    (cd "$pkg" && "$SWIFT_BIN" test --quiet)
done

if command -v xcodegen >/dev/null 2>&1 && xcode-select -p 2>/dev/null | grep -q 'Xcode.app'; then
    echo "▸ xcodegen generate"
    xcodegen generate --quiet
    echo "▸ xcodebuild StudyBotMac"
    xcodebuild -project StudyBot.xcodeproj -scheme StudyBotMac -configuration Debug \
        -derivedDataPath .build/DerivedData CODE_SIGN_IDENTITY=- build -quiet
else
    echo "▸ app build skipped (needs Xcode and xcodegen)"
fi

echo "✓ all green"

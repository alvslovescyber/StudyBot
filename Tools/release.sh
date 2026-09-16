#!/usr/bin/env bash
# Builds the Release app for copying to the other Mac (§3.6 "build once, copy the .app across").
# Output: dist/StudyBot.app and dist/StudyBot-<version>.zip. Locally signed: the first launch on
# the other Mac needs right-click → Open once (§3.10a).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
version="$(grep -E 'CFBundleShortVersionString' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
rm -rf dist && mkdir -p dist
xcodegen generate --quiet
xcodebuild -project StudyBot.xcodeproj -scheme StudyBotMac -configuration Release \
    -derivedDataPath .build/DerivedData CODE_SIGN_IDENTITY=- build -quiet
cp -R .build/DerivedData/Build/Products/Release/StudyBot.app dist/
(cd dist && ditto -c -k --keepParent StudyBot.app "StudyBot-$version.zip")
echo "✓ dist/StudyBot.app and dist/StudyBot-$version.zip (version $version)"
echo "  On the other Mac: unzip, move to /Applications, right-click → Open the first time."

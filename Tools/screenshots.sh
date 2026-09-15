#!/usr/bin/env bash
# Real screenshots of the built app, one per snapshot-tour step, into docs/screenshots.
# Usage: ./Tools/screenshots.sh [light|dark] [textSize] [WxH]
#   ./Tools/screenshots.sh dark
#   ./Tools/screenshots.sh light accessibility5 1080x600
#
# Needs a Debug build at .build/DerivedData/Build/Products/Debug/StudyBot.app and Screen
# Recording permission for the terminal running this script. The tour (SnapshotTour.swift)
# pauses at each step, writes <step>.ready with the window number, and waits for <step>.done;
# this script takes the screenshot with `screencapture -l` in between.
set -euo pipefail

appearance="${1:-light}"
text_size="${2:-}"
window="${3:-1320x800}"
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/.build/DerivedData/Build/Products/Debug/StudyBot.app"
container="$HOME/Library/Containers/com.alvisbabu.studybot/Data/tmp/snapshots-$appearance${text_size:+-$text_size}"
out="$root/docs/screenshots"
suffix="$appearance${text_size:+-$text_size}"

[[ -d "$app" ]] || { echo "build the app first: see README 'Running the app'"; exit 1; }
rm -rf "$container"
mkdir -p "$container" "$out"

env STUDYBOT_SNAPSHOT_DIR="$container" STUDYBOT_SNAPSHOT_EXTERNAL=1 \
    STUDYBOT_SNAPSHOT_APPEARANCE="$appearance" STUDYBOT_SNAPSHOT_WINDOW="$window" \
    ${text_size:+STUDYBOT_SNAPSHOT_TEXT_SIZE="$text_size"} \
    "$app/Contents/MacOS/StudyBot" &
pid=$!

seen=()
deadline=$((SECONDS + 90))
while kill -0 "$pid" 2>/dev/null && (( SECONDS < deadline )); do
    for ready in "$container"/*.ready; do
        [[ -e "$ready" ]] || continue
        step="$(basename "$ready" .ready)"
        [[ -e "$container/$step.done" ]] && continue
        sleep 0.4  # let the last animation settle
        wid="$(cat "$ready")"
        screencapture -x -o -l "$wid" "$out/$step-$suffix.png" || true
        touch "$container/$step.done"
        seen+=("$step")
    done
    sleep 0.2
done
wait "$pid" 2>/dev/null || true
echo "captured ${#seen[@]} screenshots into $out (suffix -$suffix)"

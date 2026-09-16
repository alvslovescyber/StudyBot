#!/usr/bin/env bash
# The two-machine drill (§3.11, §16) on one Mac: two copies of the Debug build, two stores,
# two device ids, one local server. Both append to Block 1's induction note while the server
# is down, the server comes back, both sync, and the script shows what each Mac holds and
# what the server archived. Real screenshots of both instances land in docs/drill/.
#
# Usage: ./Tools/drill.sh          (builds first; needs Screen Recording for the terminal)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
app="$root/.build/DerivedData/Build/Products/Debug/StudyBot.app/Contents/MacOS/StudyBot"
container="$HOME/Library/Containers/com.alvisbabu.studybot/Data"
work="$container/tmp/drill"
out="$root/docs/drill"
serverdb="$work/server.sqlite"
export STUDYBOT_DB_PATH="$serverdb" STUDYBOT_PAIRING_SECRET="drill-secret"
port=8091
ctl="$root/Server/.build/debug/studybotctl"

echo "▸ building"
xcodegen generate --quiet
xcodebuild -project StudyBot.xcodeproj -scheme StudyBotMac -configuration Debug \
    -derivedDataPath .build/DerivedData CODE_SIGN_IDENTITY=- build -quiet
(cd Server && swift build --quiet)

rm -rf "$work" "$out"; mkdir -p "$work" "$out"

server_up() {
    (nohup "$ctl" serve --hostname 127.0.0.1 --port $port >> "$work/server.log" 2>&1 &)
    for _ in $(seq 1 40); do curl -sf "http://127.0.0.1:$port/health" >/dev/null && return; sleep 0.25; done
    echo "server did not start"; exit 1
}
server_down() { pkill -f "studybotctl serve --hostname 127.0.0.1 --port $port" || true; sleep 0.5; }
pair_code() { "$ctl" pair 2>/dev/null | sed -n 's/^    //p' | head -1; }

# One instance: $1 store name, $2 device id, $3 STUDYBOT_DRILL spec, $4 optional pairing code.
run_mac() {
    local store="$work/$1.store" device="$2" spec="$3" code="${4:-}"
    rm -rf "$work/shots"; mkdir -p "$work/shots"
    env STUDYBOT_STORE_PATH="$store" STUDYBOT_DEVICE_ID="$device" STUDYBOT_DRILL="$spec" \
        STUDYBOT_SNAPSHOT_DIR="$work/shots" STUDYBOT_SNAPSHOT_EXTERNAL=1 STUDYBOT_SNAPSHOT_WINDOW=1320x800 \
        ${code:+STUDYBOT_PAIR_URL="http://127.0.0.1:$port" STUDYBOT_PAIR_CODE="$code" STUDYBOT_PAIR_NAME="$device"} \
        "$app" >> "$work/$1.log" 2>&1 &
    local pid=$!
    local deadline=$((SECONDS + 90))
    while kill -0 "$pid" 2>/dev/null && (( SECONDS < deadline )); do
        for ready in "$work"/shots/*.ready; do
            [[ -e "$ready" ]] || continue
            local step; step="$(basename "$ready" .ready)"
            [[ -e "$work/shots/$step.done" ]] && continue
            sleep 0.4
            screencapture -x -o -l "$(cat "$ready")" "$out/$step.png" || true
            touch "$work/shots/$step.done"
        done
        sleep 0.2
    done
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

echo "▸ 1. server up; both Macs pair and take their first sync"
server_up
run_mac macA mac-a show "$(pair_code)"
run_mac macB mac-b show "$(pair_code)"
"$ctl" devices 2>/dev/null

echo "▸ 2. server down; each Mac edits the same induction note offline"
server_down
run_mac macA mac-a "append:Mac A: bring the enrolment letter"
sleep 1.2   # a later, different edit on the other Mac
run_mac macB mac-b "append:Mac B: the car park code is 4471"

echo "▸ 3. server back; both reconnect"
server_up
run_mac macA mac-a show
run_mac macB mac-b show
run_mac macA mac-a show   # A pulls what B's reconnect produced

echo "▸ 4. what each Mac holds"
for mac in macA macB; do
    echo "--- $mac live notes of the induction session:"
    sqlite3 "$work/$mac.store" "select ZBODY from ZSESSIONMODEL;" \
        | python3 -c 'import sys,json
for line in sys.stdin:
    try:
        d=json.loads(line)
    except Exception: continue
    if d.get("title")=="Induction": print("   ", json.dumps(d.get("liveNotes")))'
    echo "--- $mac conflict losers kept locally:"
    sqlite3 "$work/$mac.store" "select ZRECORDTYPE, ZSERVERARCHIVEID, substr(ZBODY,1,160) from ZCONFLICTLOSERMODEL;" || true
done
echo "--- server conflict_archive (session bodies):"
sqlite3 "$serverdb" "select id, record_type, substr(body, instr(body,'liveNotes'), 120) from conflict_archive where record_type='session';"
echo "--- server: current induction note:"
sqlite3 "$serverdb" "select substr(fields, instr(fields,'liveNotes'), 160) from records where record_type='session';"
server_down
echo "✓ drill finished; screenshots in $out"

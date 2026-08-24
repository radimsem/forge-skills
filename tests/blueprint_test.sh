#!/bin/sh
# Smoke tests for blueprint's shipped machinery: serve.mjs (Task 1) and the
# composer core (Task 2). Node-only; no dependencies.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BP="$ROOT/skills/blueprint"
PASSES=0; FAILS=0
SERVER_PID=""
TMP=$(mktemp -d)
trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT INT TERM

assert_contains() { # haystack needle label
  case "$1" in
    *"$2"*) PASSES=$((PASSES+1)); echo "PASS: $3" ;;
    *) FAILS=$((FAILS+1)); echo "FAIL: $3" ;;
  esac
}
assert_not_contains() {
  case "$1" in
    *"$2"*) FAILS=$((FAILS+1)); echo "FAIL: $3" ;;
    *) PASSES=$((PASSES+1)); echo "PASS: $3" ;;
  esac
}
assert_eq() {
  if [ "$1" = "$2" ]; then PASSES=$((PASSES+1)); echo "PASS: $3"
  else FAILS=$((FAILS+1)); echo "FAIL: $3"; printf 'got:\n%s\nwant:\n%s\n' "$1" "$2"; fi
}

# --- serve.mjs: serves newest fragment, wrapped in the frame ---
mkdir -p "$TMP/.brainstorm/screens"
printf '<p>hello-fragment</p>' > "$TMP/.brainstorm/screens/first.html"
node "$BP/scripts/serve.mjs" --project-dir "$TMP" >/dev/null 2>&1 &
SERVER_PID=$!
i=0
while [ ! -f "$TMP/.brainstorm/server-info" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
[ -f "$TMP/.brainstorm/server-info" ] || { echo "FAIL: server-info never appeared"; exit 1; }
PORT=$(sed 's/.*"port":\([0-9]*\).*/\1/' "$TMP/.brainstorm/server-info")

BODY=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY" 'hello-fragment' "serves the fragment"
assert_contains "$BODY" 'blueprint-frame' "fragment is wrapped in the frame"

sleep 1.1  # ensure a newer mtime on coarse filesystems
printf '<p>second-fragment</p>' > "$TMP/.brainstorm/screens/second.html"
BODY2=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY2" 'second-fragment' "serves the newest screen"

sleep 1.1
printf '<!DOCTYPE html><html><body>raw-doc</body></html>' > "$TMP/.brainstorm/screens/third.html"
BODY3=$(curl -sf "http://127.0.0.1:$PORT/")
assert_contains "$BODY3" 'raw-doc' "full documents are served"
assert_not_contains "$BODY3" 'blueprint-frame' "full documents bypass the frame"

CSS_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/style.css")
assert_eq "$CSS_STATUS" "200" "style.css route answers even with no harvest yet"

kill "$SERVER_PID"; wait "$SERVER_PID" 2>/dev/null; SERVER_PID=""
sleep 0.3
if [ -f "$TMP/.brainstorm/server-info" ]; then
  FAILS=$((FAILS+1)); echo "FAIL: server-info removed on shutdown"
else
  PASSES=$((PASSES+1)); echo "PASS: server-info removed on shutdown"
fi

echo "PASSES=$PASSES FAILS=$FAILS"
[ "$FAILS" -eq 0 ]

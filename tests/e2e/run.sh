#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION="memd-e2e"
COLS=160
ROWS=40
TIMEOUT=10000

TUISTORY="${PROJECT_ROOT}/node_modules/.bin/tuistory"

PASSED=0
FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASSED++)) || true; }
fail() {
  echo -e "  ${RED}FAIL${NC}: $1"
  [ -n "${2:-}" ] && echo "        $2"
  ((FAILED++)) || true
}

# Wrappers that suppress tuistory's "OK" stdout
t_launch() { $TUISTORY launch "$@" >/dev/null; }
t_press()  { $TUISTORY -s "$SESSION" press "$@" >/dev/null; }
t_type()   { $TUISTORY -s "$SESSION" type "$@" >/dev/null; }
t_wait()   { $TUISTORY -s "$SESSION" wait "$@" >/dev/null; }
t_snap()   { $TUISTORY -s "$SESSION" snapshot --trim; }
t_close()  { $TUISTORY close -s "$SESSION" >/dev/null 2>/dev/null || true; }

cleanup() { t_close; }
trap cleanup EXIT

launch_nvim() {
  local file="${1:-examples/test.md}"
  local wait_text="${2:-Test Markdown}"
  local quoted_file
  quoted_file=$(printf '%q' "$file")
  cleanup
  t_launch "nvim --clean -u tests/e2e/minimal_init.lua ${quoted_file}" \
    -s "$SESSION" --cols "$COLS" --rows "$ROWS" --cwd "$PROJECT_ROOT"
  t_wait "$wait_text" --timeout "$TIMEOUT"
}

# Execute a Neovim ex command
nvim_cmd() {
  t_press esc
  sleep 0.2
  t_type ":$1"
  t_press enter
  sleep "${2:-1}"
}

# Evaluate a Vim expression and return the extracted result
nvim_eval() {
  local expr="$1"
  local ms="##ES##"
  local me="##EE##"
  t_press esc
  sleep 0.2
  t_type ":echo '${ms}' . ${expr} . '${me}'"
  t_press enter
  sleep 0.5
  t_snap | sed -n "s/.*${ms}\(.*\)${me}.*/\1/p" | head -1
}

switch_to_editor() {
  # Use F2 mapping defined in minimal_init.lua
  # (exits terminal mode and switches to left window atomically)
  t_press f2
  sleep 0.3
}

# Prerequisites
for cmd in nvim memd; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found"; exit 1; }
done
[ -x "$TUISTORY" ] || { echo "tuistory not found. Run 'pnpm install' first."; exit 1; }

echo -e "${BOLD}=== memd.nvim E2E Tests ===${NC}"
echo ""

# -----------------------------------------------------------
# Test 1: :Memd opens terminal preview
# -----------------------------------------------------------
echo -e "${BOLD}[1] :Memd opens terminal preview${NC}"
launch_nvim
nvim_cmd "Memd" 2
switch_to_editor

WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "2" ]; then
  pass ":Memd opens a split (winnr=2)"
else
  fail ":Memd opens a split" "Expected winnr=2, got '$WIN_COUNT'"
fi
cleanup

# -----------------------------------------------------------
# Test 2: :MemdClose closes terminal
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[2] :MemdClose closes terminal${NC}"
launch_nvim
nvim_cmd "Memd" 2
switch_to_editor
nvim_cmd "MemdClose" 1

WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "1" ]; then
  pass ":MemdClose restores single window (winnr=1)"
else
  fail ":MemdClose restores single window" "Expected winnr=1, got '$WIN_COUNT'"
fi
cleanup

# -----------------------------------------------------------
# Test 3: :MemdToggle opens and closes
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[3] :MemdToggle opens and closes${NC}"
launch_nvim

# Toggle on
nvim_cmd "MemdToggle" 2
switch_to_editor
WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "2" ]; then
  pass ":MemdToggle opens split (winnr=2)"
else
  fail ":MemdToggle opens split" "Expected winnr=2, got '$WIN_COUNT'"
fi

# Toggle off (already in editor from switch above)
nvim_cmd "MemdToggle" 1
WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "1" ]; then
  pass ":MemdToggle closes split (winnr=1)"
else
  fail ":MemdToggle closes split" "Expected winnr=1, got '$WIN_COUNT'"
fi
cleanup

# -----------------------------------------------------------
# Test 4: Auto-reload preserves editor focus
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[4] Auto-reload preserves editor focus${NC}"

TMPFILE="${PROJECT_ROOT}/tests/e2e/tmp_test.md"
cp "${PROJECT_ROOT}/examples/test.md" "$TMPFILE"
trap 'rm -f "$TMPFILE"; cleanup' EXIT

launch_nvim "tests/e2e/tmp_test.md"
nvim_cmd "Memd" 2
switch_to_editor

# Edit and save to trigger fs_watcher auto-reload
t_press esc
t_type "oFOCUS_TEST_LINE"
t_press esc
nvim_cmd "w" 3

# Verify focus is on editor by checking current buffer name
BUF_NAME=$(nvim_eval "bufname('%')")
if echo "$BUF_NAME" | grep -q "tmp_test"; then
  pass "Focus stays on editor after auto-reload (buf=$BUF_NAME)"
elif echo "$BUF_NAME" | grep -q "memd://"; then
  fail "Focus stays on editor after auto-reload" "Focus on memd terminal (buf=$BUF_NAME)"
else
  fail "Focus stays on editor after auto-reload" "Unexpected buffer: '$BUF_NAME'"
fi

# Also verify memd split is still open after reload
WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "2" ]; then
  pass "Memd split survives auto-reload (winnr=2)"
else
  fail "Memd split survives auto-reload" "Expected winnr=2, got '$WIN_COUNT'"
fi

rm -f "$TMPFILE"
cleanup
trap cleanup EXIT

# -----------------------------------------------------------
# Test 5: Auto-reload fires on consecutive saves (inode replacement)
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[5] Auto-reload fires on consecutive saves${NC}"

TMPFILE="${PROJECT_ROOT}/tests/e2e/tmp_reload.md"
cat > "$TMPFILE" <<'EOF'
# Reload Test

Initial content
EOF
trap 'rm -f "$TMPFILE"; cleanup' EXIT

launch_nvim "tests/e2e/tmp_reload.md" "Initial content"
nvim_cmd "Memd" 2
switch_to_editor

# 1st edit + save
t_press esc
t_type "GoRELOAD_ROUND_1"
t_press esc
nvim_cmd "w" 3

SNAP1=$(t_snap)
if echo "$SNAP1" | grep -q "RELOAD_ROUND_1"; then
  pass "1st save: preview updated (RELOAD_ROUND_1 found)"
else
  fail "1st save: preview updated" "RELOAD_ROUND_1 not found in snapshot"
fi

# 2nd edit + save (this is the regression case)
t_type "GoRELOAD_ROUND_2"
t_press esc
nvim_cmd "w" 3

SNAP2=$(t_snap)
if echo "$SNAP2" | grep -q "RELOAD_ROUND_2"; then
  pass "2nd save: preview updated (RELOAD_ROUND_2 found)"
else
  fail "2nd save: preview updated" "RELOAD_ROUND_2 not found in snapshot"
fi

# 3rd edit + save (extra confidence)
t_type "GoRELOAD_ROUND_3"
t_press esc
nvim_cmd "w" 3

SNAP3=$(t_snap)
if echo "$SNAP3" | grep -q "RELOAD_ROUND_3"; then
  pass "3rd save: preview updated (RELOAD_ROUND_3 found)"
else
  fail "3rd save: preview updated" "RELOAD_ROUND_3 not found in snapshot"
fi

rm -f "$TMPFILE"
cleanup
trap cleanup EXIT

# -----------------------------------------------------------
# Test 6: Floating mode open/close
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[6] Floating mode open/close${NC}"
launch_nvim

nvim_cmd "lua require('memd').open_terminal({display_mode='floating', focus=false})" 2

WIN_COUNT=$(nvim_eval "len(nvim_list_wins())")
if [ "$WIN_COUNT" = "2" ]; then
  pass "Floating mode opens (nvim_list_wins=2)"
else
  fail "Floating mode opens" "Expected nvim_list_wins=2, got '$WIN_COUNT'"
fi

nvim_cmd "MemdClose" 1
WIN_COUNT=$(nvim_eval "len(nvim_list_wins())")
if [ "$WIN_COUNT" = "1" ]; then
  pass "Floating mode closes (nvim_list_wins=1)"
else
  fail "Floating mode closes" "Expected nvim_list_wins=1, got '$WIN_COUNT'"
fi
cleanup

# -----------------------------------------------------------
# Test 7: :Memd called twice replaces preview
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[7] :Memd called twice replaces preview${NC}"
launch_nvim
nvim_cmd "Memd" 2
switch_to_editor

# Call :Memd again - should replace, not add another split
nvim_cmd "Memd" 2
switch_to_editor

WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "2" ]; then
  pass ":Memd twice keeps winnr=2 (no duplicate splits)"
else
  fail ":Memd twice keeps winnr=2" "Expected winnr=2, got '$WIN_COUNT'"
fi
cleanup

# -----------------------------------------------------------
# Test 8: :Memd on non-markdown file shows warning
# -----------------------------------------------------------
echo ""
echo -e "${BOLD}[8] :Memd on non-markdown file shows warning${NC}"

TMPFILE_TXT="${PROJECT_ROOT}/tests/e2e/tmp_test.txt"
echo "not markdown" > "$TMPFILE_TXT"
trap 'rm -f "$TMPFILE_TXT"; cleanup' EXIT

launch_nvim "tests/e2e/tmp_test.txt" "not markdown"
nvim_cmd "Memd" 1

# Check warning message first (before nvim_eval clears it)
SNAP=$(t_snap)
if echo "$SNAP" | grep -q "not a markdown file"; then
  pass "Warning message shown for non-markdown file"
else
  fail "Warning message shown" "Expected 'not a markdown file' in snapshot"
fi

WIN_COUNT=$(nvim_eval 'winnr("$")')
if [ "$WIN_COUNT" = "1" ]; then
  pass ":Memd refused on non-markdown (winnr=1)"
else
  fail ":Memd refused on non-markdown" "Expected winnr=1, got '$WIN_COUNT'"
fi

rm -f "$TMPFILE_TXT"
cleanup
trap cleanup EXIT

# -----------------------------------------------------------
# Summary
# -----------------------------------------------------------
echo ""
TOTAL=$((PASSED + FAILED))
echo -e "${BOLD}=== Results: ${GREEN}${PASSED}${NC}${BOLD}/${TOTAL} passed ===${NC}"
[ "$FAILED" -gt 0 ] && exit 1
exit 0

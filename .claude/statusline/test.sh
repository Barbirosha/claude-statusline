#!/bin/bash
# Runs statusline.sh against mock input and checks the output.
# Usage: bash .claude/statusline/test.sh
set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
mkdir -p "$HOME"

REPO="$WORK/sample-app"
git init -q -b feature/demo "$REPO"
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

mock() {
  printf '{"model":{"display_name":"Opus 5.5"},"effort":{"level":"high"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":%s,"total_input_tokens":%s,"context_window_size":1000000},"cost":{"total_cost_usd":12.4,"total_duration_ms":4320000}%s}' \
    "$REPO" "$1" "$2" "$3"
}

plain() {
  NO_COLOR=1 "$SCRIPT"
}

out=$(mock 27 272000 "" | plain)
first_line=$(printf '%s\n' "$out" | head -1)
case "$first_line" in
  "sample-app │ feature/demo │ Opus 5.5 ● high │ \$12.40 │ ⏱ 1h12m") ;;
  *) fail "line 1 order or content: $first_line" ;;
esac
printf '%s\n' "$out" | grep -q '^context  ▰▰▱▱▱▱▱▱▱▱  27% 272k/1M  ▲ 250k+' || fail "context row with threshold badge"
printf '%s\n' "$out" | grep -q 'run /compact' || fail "compact advice at 250k"
printf '%s\n' "$out" | grep -q '^current' && fail "limit rows must be hidden without rate_limits"

mock 100 100000 "" | plain | grep -q '▲' && fail "no badge below 250k"
mock 54 540000 "" | plain | grep -q '▲▲ 500k+' || fail "red badge at 500k"
mock 54 540000 "" | plain | grep -q 'run /clear' || fail "clear advice at 500k"

limits=',"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":4102444800}}'
mock 10 100000 "$limits" | plain | grep -q '^current  .*93%  !' || fail "5h row with ! badge at 90%+"

mock 27 272000 "" | NO_COLOR=1 "$SCRIPT" | grep -q $'\033' && fail "NO_COLOR output has escape codes"
mock 27 272000 "" | "$SCRIPT" | grep -q $'\033\\[38;5;110m' || fail "nord is the default theme"

echo '{}' | "$SCRIPT" > /dev/null || fail "empty input must exit 0"

"$SCRIPT" --set-theme dracula > /dev/null || fail "--set-theme accepts a known theme"
[ "$(cat "$HOME/.claude/statusline-theme")" = "dracula" ] || fail "--set-theme writes the per-user theme file"
mock 27 272000 "" | "$SCRIPT" | grep -q $'\033\\[38;5;141m' || fail "saved theme is used"
"$SCRIPT" --set-theme nope > /dev/null 2>&1 && fail "--set-theme rejects an unknown theme"

if [ "$failures" -eq 0 ]; then
  echo "all statusline checks passed"
else
  echo "$failures statusline check(s) failed"
  exit 1
fi

#!/bin/bash
# Claude Code status line.
# Line 1: directory, git branch, model and effort, cost, session time.
# From line 2, labelled rows: context (with tokens), current / weekly rate limits, spend limit in dollars. Then advice, when needed.
THEMES="nord default dracula gruvbox solarized neon pastel mono"
THEME_FILE="${CLAUDE_STATUSLINE_THEME_FILE:-$HOME/.claude/statusline-theme}"

case "$1" in
  --themes)
    sample=$(printf '{"model":{"display_name":"Opus 5.5"},"effort":{"level":"high"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":27,"total_input_tokens":272000,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":%s},"seven_day":{"used_percentage":93,"resets_at":%s}},"cost":{"total_cost_usd":12.4,"total_duration_ms":4320000}}' "$PWD" "$(( $(date +%s) + 8000 ))" "$(( $(date +%s) + 270000 ))")
    for name in $THEMES; do
      printf '\n[%s]\n' "$name"
      printf '%s' "$sample" | CLAUDE_STATUSLINE_THEME="$name" "$0"
    done
    exit 0 ;;
  --set-theme)
    case " $THEMES " in
      *" $2 "*) mkdir -p "$(dirname "$THEME_FILE")" && printf '%s\n' "$2" > "$THEME_FILE"; echo "theme set to $2" ;;
      *) echo "unknown theme '$2'. available: $THEMES"; exit 1 ;;
    esac
    exit 0 ;;
esac

input=$(cat)

eval "$(printf '%s' "$input" | jq -r '
  @sh "MODEL=\(.model.display_name // "")",
  @sh "EFFORT=\(.effort.level // "")",
  @sh "DIR=\(.workspace.current_dir // .cwd // "")",
  @sh "PCT=\((.context_window.used_percentage // -1) | floor)",
  @sh "USED=\(.context_window.total_input_tokens // 0)",
  @sh "WINDOW=\(.context_window.context_window_size // 0)",
  @sh "H5=\((.rate_limits.five_hour.used_percentage // -1) | floor)",
  @sh "R5=\(.rate_limits.five_hour.resets_at // 0)",
  @sh "D7=\((.rate_limits.seven_day.used_percentage // -1) | floor)",
  @sh "R7=\(.rate_limits.seven_day.resets_at // 0)",
  @sh "COST=\(.cost.total_cost_usd // 0)",
  @sh "DURATION_MS=\(.cost.total_duration_ms // 0)",
  @sh "SPEND_PCT=\((.rate_limits.spend_limit.used_percentage // -1) | floor)",
  @sh "SPEND_USED=\(.rate_limits.spend_limit.used_usd // -1)",
  @sh "SPEND_LIMIT=\(.rate_limits.spend_limit.limit_usd // -1)",
  @sh "SPEND_PERIOD=\(.rate_limits.spend_limit.period // "")",
  @sh "SPEND_RESET=\(.rate_limits.spend_limit.resets_at // 0)"
')"

TOKEN_ALERT=250000
TOKEN_ALERT_HIGH=500000
BAR_WIDTH=10

THEME="${CLAUDE_STATUSLINE_THEME:-$(cat "$THEME_FILE" 2>/dev/null)}"
THEME=${THEME:-nord}
BADGE_RED_TEXT=231
case "$THEME" in
  nord)      C_BLUE=110 C_ORANGE=173 C_GREEN=108 C_CYAN=116 C_RED=167 C_YELLOW=222 C_WHITE=253 C_MAGENTA=139 ;;
  dracula)   C_BLUE=141 C_ORANGE=215 C_GREEN=84  C_CYAN=117 C_RED=203 C_YELLOW=228 C_WHITE=255 C_MAGENTA=212 ;;
  gruvbox)   C_BLUE=109 C_ORANGE=208 C_GREEN=142 C_CYAN=108 C_RED=167 C_YELLOW=214 C_WHITE=223 C_MAGENTA=175 ;;
  solarized) C_BLUE=33  C_ORANGE=166 C_GREEN=64  C_CYAN=37  C_RED=160 C_YELLOW=136 C_WHITE=245 C_MAGENTA=125 ;;
  neon)      C_BLUE=45  C_ORANGE=208 C_GREEN=46  C_CYAN=51  C_RED=196 C_YELLOW=226 C_WHITE=231 C_MAGENTA=201 ;;
  pastel)    C_BLUE=111 C_ORANGE=216 C_GREEN=114 C_CYAN=152 C_RED=210 C_YELLOW=229 C_WHITE=253 C_MAGENTA=183 ;;
  mono)      C_BLUE=252 C_ORANGE=250 C_GREEN=247 C_CYAN=249 C_RED=255 C_YELLOW=251 C_WHITE=253 C_MAGENTA=254 BADGE_RED_TEXT=16 ;;
  *)         C_BLUE=39  C_ORANGE=215 C_GREEN=35  C_CYAN=73  C_RED=203 C_YELLOW=220 C_WHITE=253 C_MAGENTA=141 ;;
esac

if [ -n "$NO_COLOR" ]; then
  RST='' DIM='' BLUE='' ORANGE='' GREEN='' CYAN='' RED='' YELLOW='' WHITE='' MAGENTA='' BADGE_ORANGE='' BADGE_RED=''
else
  RST=$'\033[0m' DIM=$'\033[2m'
  BLUE=$'\033[38;5;'"${C_BLUE}"m ORANGE=$'\033[38;5;'"${C_ORANGE}"m GREEN=$'\033[38;5;'"${C_GREEN}"m
  CYAN=$'\033[38;5;'"${C_CYAN}"m RED=$'\033[38;5;'"${C_RED}"m YELLOW=$'\033[38;5;'"${C_YELLOW}"m
  WHITE=$'\033[38;5;'"${C_WHITE}"m MAGENTA=$'\033[38;5;'"${C_MAGENTA}"m
  BADGE_ORANGE=$'\033[1;38;5;16;48;5;'"${C_ORANGE}"m
  BADGE_RED=$'\033[1;38;5;'"${BADGE_RED_TEXT}"$';48;5;'"${C_RED}"m
fi
SEP=" ${DIM}│${RST} "

color_for_pct() {
  if [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
  elif [ "$1" -ge 50 ]; then printf '%s' "$ORANGE"
  else printf '%s' "$GREEN"
  fi
}

build_bar() {
  local pct=$1 color=${2:-$(color_for_pct "$1")} filled i full="" empty=""
  [ "$pct" -gt 100 ] && pct=100
  filled=$(( pct * BAR_WIDTH / 100 ))
  for ((i = 0; i < BAR_WIDTH; i++)); do
    if [ "$i" -lt "$filled" ]; then full="${full}▰"; else empty="${empty}▱"; fi
  done
  printf '%s%s%s%s%s' "$color" "$full" "$DIM" "$empty" "$RST"
}

# Context colour follows the token thresholds, and the percentage thresholds when those are worse.
context_color() {
  if [ "$USED" -ge "$TOKEN_ALERT_HIGH" ] || [ "$PCT" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$USED" -ge "$TOKEN_ALERT" ] || [ "$PCT" -ge 70 ]; then printf '%s' "$ORANGE"
  else printf '%s' "$GREEN"
  fi
}

fmt_tokens() {
  if [ "$1" -ge 1000000 ]; then
    local tenth=$(( ($1 % 1000000) / 100000 ))
    if [ "$tenth" -eq 0 ]; then printf '%sM' $(( $1 / 1000000 )); else printf '%s.%sM' $(( $1 / 1000000 )) "$tenth"; fi
  elif [ "$1" -ge 1000 ]; then printf '%sk' $(( $1 / 1000 ))
  else printf '%s' "$1"
  fi
}

fmt_session() {
  local mins=$(( $1 / 60000 ))
  [ "$mins" -ge 1 ] || return
  if [ "$mins" -ge 60 ]; then printf '%sh%sm' $(( mins / 60 )) $(( mins % 60 )); else printf '%sm' "$mins"; fi
}

fmt_epoch() {
  [ "$1" -gt 0 ] || return
  local out
  out=$(date -j -r "$1" +"$2" 2>/dev/null || date -d "@$1" +"$2" 2>/dev/null)
  printf '%s' "$out" | sed 's/  / /g; s/^ //' | tr '[:upper:]' '[:lower:]'
}

badge() {
  printf '%s %s %s' "$1" "$2" "$RST"
}

git_segment() {
  [ -n "$DIR" ] || return
  local cache="${TMPDIR:-/tmp}/claude-statusline-git-$(printf '%s' "$DIR" | cksum | cut -d' ' -f1)"
  local mtime
  mtime=$(stat -f %m "$cache" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - mtime )) -ge 5 ]; then
    if GIT_OPTIONAL_LOCKS=0 git -C "$DIR" status --porcelain=v2 --branch > "$cache.tmp" 2>/dev/null; then
      mv "$cache.tmp" "$cache"
    else
      rm -f "$cache.tmp"
      [ -e "$cache" ] || : > "$cache"
      touch "$cache"
    fi
  fi

  local branch ahead behind dirty out
  branch=$(sed -n 's/^# branch.head //p' "$cache")
  [ -n "$branch" ] || return
  [ "$branch" = "(detached)" ] && branch=$(sed -n 's/^# branch.oid \(.\{7\}\).*/@\1/p' "$cache")
  read -r ahead behind <<< "$(sed -n 's/^# branch.ab +\([0-9]*\) -\([0-9]*\)/\1 \2/p' "$cache")"
  dirty=$(grep -c -E '^(1|2|u|\?) ' "$cache" || true)

  out="${GREEN}${branch}${RST}"
  [ "${dirty:-0}" -gt 0 ] && out="${out}${RED}*${RST}"
  [ "${ahead:-0}" -gt 0 ] && out="$out ${GREEN}↑${ahead}${RST}"
  [ "${behind:-0}" -gt 0 ] && out="$out ${RED}↓${behind}${RST}"
  printf '%s' "$out"
}

context_row() {
  [ "$PCT" -ge 0 ] || return
  local color
  color=$(context_color)
  printf '%s%-8s%s %s %s%3d%%%s' "$WHITE" "context" "$RST" "$(build_bar "$PCT" "$color")" "$color" "$PCT" "$RST"
  [ "$WINDOW" -gt 0 ] && printf ' %s%s%s%s/%s%s' "$color" "$(fmt_tokens "$USED")" "$RST" "$DIM" "$(fmt_tokens "$WINDOW")" "$RST"
  if [ "$USED" -ge "$TOKEN_ALERT_HIGH" ]; then
    printf ' %s' "$(badge "$BADGE_RED" "▲▲ $(fmt_tokens "$TOKEN_ALERT_HIGH")+")"
  elif [ "$USED" -ge "$TOKEN_ALERT" ]; then
    printf ' %s' "$(badge "$BADGE_ORANGE" "▲ $(fmt_tokens "$TOKEN_ALERT")+")"
  fi
  printf '\n'
}

effort_segment() {
  case "$EFFORT" in
    '') return ;;
    high|xhigh|max) printf '%s● %s%s' "$MAGENTA" "$EFFORT" "$RST" ;;
    low) printf '%s◔ %s%s' "$DIM" "$EFFORT" "$RST" ;;
    *) printf '%s◑ %s%s' "$DIM" "$EFFORT" "$RST" ;;
  esac
}

join() {
  local out=$1 seg
  shift
  for seg in "$@"; do
    [ -n "$seg" ] && out="${out:+$out$SEP}$seg"
  done
  printf '%s' "$out"
}

limit_row() {
  [ "$2" -ge 0 ] || return
  local reset
  reset=$(fmt_epoch "$3" "$4")
  printf '%s%-8s%s %s %s%3d%%%s' "$WHITE" "$1" "$RST" "$(build_bar "$2")" "$(color_for_pct "$2")" "$2" "$RST"
  [ "$2" -ge 90 ] && printf ' %s' "$(badge "$BADGE_RED" "!")"
  [ -n "$reset" ] && printf ' %s⟳%s %s%s%s' "$DIM" "$RST" "$WHITE" "$reset" "$RST"
  printf '\n'
}

cost_segment() {
  local cents
  cents=$(awk -v c="$COST" 'BEGIN { printf "%d", c * 100 }')
  [ "$cents" -gt 0 ] || return
  local color=$YELLOW
  [ "$cents" -ge 1000 ] && color=$ORANGE
  [ "$cents" -ge 3000 ] && color=$RED
  printf '%s$%d.%02d%s' "$color" $(( cents / 100 )) $(( cents % 100 )) "$RST"
}

spend_row() {
  [ "$SPEND_PCT" -ge 0 ] || return
  local reset dollars
  reset=$(fmt_epoch "$SPEND_RESET" "%b %-d")
  printf '%s%-8s%s %s %s%3d%%%s' "$WHITE" "spend" "$RST" "$(build_bar "$SPEND_PCT")" "$(color_for_pct "$SPEND_PCT")" "$SPEND_PCT" "$RST"
  [ "$SPEND_PCT" -ge 90 ] && printf ' %s' "$(badge "$BADGE_RED" "!")"
  if awk -v u="$SPEND_USED" -v l="$SPEND_LIMIT" 'BEGIN { exit !(u >= 0 && l > 0) }'; then
    dollars=$(awk -v u="$SPEND_USED" -v l="$SPEND_LIMIT" 'BEGIN { printf "$%.2f/$%.2f", u, l }')
    printf ' %s%s%s' "$WHITE" "$dollars" "$RST"
    [ -n "$SPEND_PERIOD" ] && printf ' %s%s%s' "$DIM" "$SPEND_PERIOD" "$RST"
  fi
  [ -n "$reset" ] && printf ' %s⟳%s %s%s%s' "$DIM" "$RST" "$WHITE" "$reset" "$RST"
  printf '\n'
}

advice_lines() {
  local tokens
  tokens=$(fmt_tokens "$USED")
  if [ "$USED" -ge "$TOKEN_ALERT_HIGH" ]; then
    printf '%s→ Context %s: run /clear or start a new session, every turn is now very expensive%s\n' "$RED" "$tokens" "$RST"
  elif [ "$USED" -ge "$TOKEN_ALERT" ]; then
    printf '%s→ Context %s: run /compact to make every next turn cheaper%s\n' "$ORANGE" "$tokens" "$RST"
  fi
  [ "$H5" -ge 90 ] && printf '%s→ 5h limit almost used up (%s%%): take a break until it resets%s\n' "$RED" "$H5" "$RST"
  [ "$D7" -ge 90 ] && printf '%s→ 7d limit almost used up (%s%%): go easy on requests%s\n' "$RED" "$D7" "$RST"
  [ "$SPEND_PCT" -ge 90 ] && printf '%s→ Spend limit almost used up (%s%%): go easy on requests%s\n' "$RED" "$SPEND_PCT" "$RST"
  return 0
}

model_name=""
[ -n "$MODEL" ] && model_name="${BLUE}${MODEL}${RST}"
effort=$(effort_segment)
[ -n "$model_name" ] && [ -n "$effort" ] && model_name="$model_name $effort"
dir_name=""
[ -n "$DIR" ] && dir_name="${CYAN}$(basename "$DIR")${RST}"
duration=$(fmt_session "$DURATION_MS")
[ -n "$duration" ] && duration="${DIM}⏱ ${RST}${WHITE}${duration}${RST}"

join "$dir_name" "$(git_segment)" "$model_name" "$(cost_segment)" "$duration"
printf '\n'

rows=""
for row in "$(context_row)" "$(limit_row current "$H5" "$R5" "%l:%M%p")" "$(limit_row weekly "$D7" "$R7" "%b %-d, %l:%M%p")" "$(spend_row)"; do
  [ -n "$row" ] && rows="${rows:+$rows$'\n'}$row"
done
[ -n "$rows" ] && printf '%s\n' "$rows"
advice_lines

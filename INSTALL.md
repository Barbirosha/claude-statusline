# Status line — install into any repo

1. Copy the `.claude/statusline/` folder into your repo root.
2. Add the `statusLine` block from `.claude/settings.json` into your repo's
   `.claude/settings.json` (merge it if the file already exists).
3. Commit both. Everyone who opens the repo in Claude Code gets the status line.

Requires: bash, jq, git (macOS `date -j`, GNU `date -d` fallback).
A personal theme lives in ~/.claude/statusline-theme (never committed).

Test:  bash .claude/statusline/test.sh

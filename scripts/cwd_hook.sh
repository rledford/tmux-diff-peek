#!/usr/bin/env sh

[ -z "$TMUX_PANE" ] && exit 0

cache_dir="$HOME/.cache/tmux-diff-peek"
mkdir -p "$cache_dir" 2>/dev/null || exit 0

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
else
  cwd="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

[ -z "$cwd" ] && exit 0

pane_file="$cache_dir/${TMUX_PANE#%}.cwd"
tmp_file="$pane_file.$$"
printf '%s\n' "$cwd" > "$tmp_file" && mv "$tmp_file" "$pane_file"

exit 0

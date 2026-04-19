#!/usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/helpers.sh"

pane_id="$1"
pane_pid="$2"
pane_current_path="$3"

git_dir="$(resolve_git_cwd "$pane_pid" "$pane_current_path")"

if ! git -C "$git_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tmux set-option -pt "$pane_id" @git_status ""
  exit 0
fi

branch="$(git -C "$git_dir" symbolic-ref --short HEAD 2>/dev/null)"
[ -z "$branch" ] && branch="$(git -C "$git_dir" rev-parse --short HEAD 2>/dev/null)"

modified="$(git -C "$git_dir" diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
staged="$(git -C "$git_dir" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
untracked="$(git -C "$git_dir" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"

status=""
[ "$modified" -gt 0 ] && status="$status ●$modified"
[ "$staged" -gt 0 ] && status="$status +$staged"
[ "$untracked" -gt 0 ] && status="$status ?$untracked"

tmux set-option -pt "$pane_id" @git_status "$branch$status"

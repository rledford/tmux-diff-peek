#!/usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/helpers.sh"

pane_id="$(tmux display-message -p "#{pane_id}")"
pane_current_path="$(tmux display-message -p "#{pane_current_path}")"

git_dir="$(resolve_git_cwd "$pane_id" "$pane_current_path")"

check_git_repo "$git_dir" || exit 0

if has_staged "$git_dir"; then
  tmux display-message "diff-peek: no staged changes"
  exit 0
fi

width="$(get_tmux_option "$DIFF_PEEK_WIDTH_OPTION" "$DIFF_PEEK_WIDTH_DEFAULT")"
height="$(get_tmux_option "$DIFF_PEEK_HEIGHT_OPTION" "$DIFF_PEEK_HEIGHT_DEFAULT")"

tmux display-popup -E -d "$git_dir" -w "$width" -h "$height" -T " git diff --staged " -- \
  sh -c 'DELTA_PAGER="less -R" LESS=R git diff --cached'

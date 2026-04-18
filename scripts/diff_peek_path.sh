#!/usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/helpers.sh"

raw_path="$1"

if [ -z "$raw_path" ]; then
  tmux display-message "diff-peek: no path provided"
  exit 1
fi

pane_path="$(tmux display-message -p "#{pane_current_path}")"

resolved_path="$(resolve_path "$raw_path" "$pane_path")"

check_git_repo "$resolved_path" || exit 1

if has_diff "$resolved_path" "$resolved_path"; then
  tmux display-message "diff-peek: no changes at $resolved_path"
  exit 0
fi

width="$(get_tmux_option "$DIFF_PEEK_WIDTH_OPTION" "$DIFF_PEEK_WIDTH_DEFAULT")"
height="$(get_tmux_option "$DIFF_PEEK_HEIGHT_OPTION" "$DIFF_PEEK_HEIGHT_DEFAULT")"

tmux display-popup -E -d "$resolved_path" -w "$width" -h "$height" -T " git diff " -- git diff "$resolved_path"

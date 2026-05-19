#!/usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/helpers.sh"

pane_id="$(tmux display-message -p "#{pane_id}")"
pane_current_path="$(tmux display-message -p "#{pane_current_path}")"

git_dir="$(resolve_git_cwd "$pane_id" "$pane_current_path")"

check_git_repo "$git_dir" || exit 0

if has_diff "$git_dir" && ! has_untracked "$git_dir"; then
  tmux display-message "diff-peek: no unstaged or untracked changes"
  exit 0
fi

if ! command -v nvim >/dev/null 2>&1; then
  tmux display-message "diff-peek: nvim not found in PATH"
  exit 0
fi

width="$(get_tmux_option "$DIFF_PEEK_WIDTH_OPTION" "$DIFF_PEEK_WIDTH_DEFAULT")"
height="$(get_tmux_option "$DIFF_PEEK_HEIGHT_OPTION" "$DIFF_PEEK_HEIGHT_DEFAULT")"
clipboard_cmd="$(get_tmux_option "$DIFF_PEEK_CLIPBOARD_COMMAND_OPTION" "$DIFF_PEEK_CLIPBOARD_COMMAND_DEFAULT")"
export_key="$(get_tmux_option "$DIFF_PEEK_EXPORT_KEY_OPTION" "$DIFF_PEEK_EXPORT_KEY_DEFAULT")"

tmpfile="$(mktemp -t tmux-diff-peek.XXXXXX)"
trap 'rm -f "$tmpfile"' EXIT INT TERM

build_unstaged_diff "$git_dir" "$tmpfile"

tmux display-popup -E -d "$git_dir" -w "$width" -h "$height" -T " diff-peek review " \
  -e "NVIM_APPNAME=tmux-diff-peek" \
  -e "TMUX_DIFF_PEEK_CLIPBOARD_CMD=$clipboard_cmd" \
  -e "TMUX_DIFF_PEEK_EXPORT_KEY=$export_key" \
  -- nvim -n -R "$tmpfile"

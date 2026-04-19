#!/usr/bin/env sh

PLUGIN_DIR=$(cd "$(dirname "$0")" && pwd)

. "$PLUGIN_DIR/scripts/variables.sh"
. "$PLUGIN_DIR/scripts/helpers.sh"

key=$(get_tmux_option "$DIFF_PEEK_KEY_OPTION" "$DIFF_PEEK_KEY_DEFAULT")
staged_key=$(get_tmux_option "$DIFF_PEEK_STAGED_KEY_OPTION" "$DIFF_PEEK_STAGED_KEY_DEFAULT")

tmux bind-key "$key" run-shell "$PLUGIN_DIR/scripts/diff_peek.sh"
tmux bind-key "$staged_key" run-shell "$PLUGIN_DIR/scripts/diff_peek_staged.sh"

tmux set-hook -g pane-focus-in "run-shell '$PLUGIN_DIR/scripts/git_status.sh #{pane_id} #{pane_pid} #{pane_current_path}'"

exit 0

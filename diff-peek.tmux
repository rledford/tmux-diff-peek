#!/usr/bin/env sh

PLUGIN_DIR=$(cd "$(dirname "$0")" && pwd)

. "$PLUGIN_DIR/scripts/variables.sh"
. "$PLUGIN_DIR/scripts/helpers.sh"

key=$(get_tmux_option "$DIFF_PEEK_KEY_OPTION" "$DIFF_PEEK_KEY_DEFAULT")
path_key=$(get_tmux_option "$DIFF_PEEK_PATH_KEY_OPTION" "$DIFF_PEEK_PATH_KEY_DEFAULT")

tmux bind-key "$key" run-shell "$PLUGIN_DIR/scripts/diff_peek.sh"
tmux bind-key "$path_key" command-prompt -p "Path:" "run-shell '$PLUGIN_DIR/scripts/diff_peek_path.sh \"%%\"'"

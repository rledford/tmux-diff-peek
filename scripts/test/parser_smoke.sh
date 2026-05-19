#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

mkdir -p "$HOME/.config"
if [ "$(readlink "$HOME/.config/tmux-diff-peek" 2>/dev/null)" != "$PLUGIN_ROOT/nvim" ]; then
  ln -sfn "$PLUGIN_ROOT/nvim" "$HOME/.config/tmux-diff-peek"
fi

NVIM_APPNAME=tmux-diff-peek nvim --headless -c 'lua require("diff_peek.parser_test").run()' -c 'qa!' || exit $?

FIXTURE="$PLUGIN_ROOT/nvim/lua/diff_peek/fixtures/multi_hunk.diff"
REAL_LAUNCH_CHECK='lua local p = require("diff_peek.parser"); local b = vim.fn.bufnr("multi_hunk.diff"); if b == -1 then io.stderr:write("real-launch: diff buffer not loaded\n"); vim.cmd("cq") end; local entry = p.line_to_location(b, 6); if not entry then io.stderr:write("real-launch: parser cache empty after BufReadPost\n"); vim.cmd("cq") else io.stdout:write(string.format("real-launch: L6=%s/%d\n", entry.kind, entry.file_line or -1)) end'

real_launch_out="$(NVIM_APPNAME=tmux-diff-peek nvim --headless -n -R -c "edit $FIXTURE" -c "$REAL_LAUNCH_CHECK" -c 'qa!' 2>&1)"
real_launch_status=$?
echo "$real_launch_out"
if [ $real_launch_status -ne 0 ]; then
  echo "real-launch smoke: FAIL" >&2
  exit $real_launch_status
fi
echo "$real_launch_out" | grep -q "real-launch: L6=context/10" || {
  echo "real-launch smoke: FAIL — unexpected output" >&2
  exit 1
}
echo "real-launch smoke: PASS"

# tmux-diff-peek

A tmux plugin that shows git diffs in a popup overlay without leaving your current workflow.

## What It Does

`tmux-diff-peek` provides two keybindings that open an interactive code-review popup for the current pane's git context. The popup runs neovim inside a `display-popup -E` overlay with a vertical split — a read-only diff buffer on the left and a writable comments buffer on the right.

- `<prefix>-g` — Reviews unstaged changes plus untracked files.
- `<prefix>-G` — Reviews staged changes (`git diff --cached`).

The working directory is taken from `#{pane_current_path}` by default, or from a per-pane cache file populated by an agent hook (see [Agent CWD Hook](#agent-cwd-hook)).

### Selection-to-comment flow

In the diff buffer, select one or more diff lines with vim's `v` motion (or `V` for full lines), then press `<Enter>` to spawn a comment block in the right-hand buffer. Each block contains a markdown header with the file path and line range, a fenced ` ```diff ` snippet of the selected lines, and a blank line for your comment. After insertion, focus jumps to the new block in insert mode.

Selections that span multiple files, multiple hunks, only removed lines, binary banners, or rename-only blocks are rejected with a transient message and no block is produced.

### Navigating between diff and comments

`<C-h>` jumps to the diff buffer and `<C-l>` jumps to the comments buffer. They work in normal, insert, and visual modes — so after typing a comment you can press `<C-h>` to jump straight back to the diff and start another selection without first leaving insert mode.

In insert mode this overrides the default `<C-h>` = backspace. Use `<BS>` or `<Del>` to delete characters.

### Export

Press `<leader>x` in the comments buffer (configurable — see [`@diff-peek-export-key`](#diff-peek-export-key)) to copy all comments as markdown to the system clipboard via `pbcopy` (configurable — see [`@diff-peek-clipboard-command`](#diff-peek-clipboard-command)). Empty-body blocks are filtered out. A transient message reports how many blocks were copied. The popup stays open until you dismiss neovim with `:qa`; exiting without exporting has no clipboard side effects.

The plugin uses its own neovim config (under `nvim/` inside the plugin) selected via `NVIM_APPNAME`, so it does not inherit or interfere with your normal `~/.config/nvim/` setup. The plugin sets its own leader (`<Space>`) before binding the export key.

## Requirements

- tmux >= 3.2
- neovim >= 0.9
- `pbcopy` (macOS) for clipboard export, or an override via [`@diff-peek-clipboard-command`](#diff-peek-clipboard-command)

## Installation

### Via TPM (Tmux Plugin Manager)

Add the following to your `~/.tmux.conf`:

```tmux
set -g @plugin 'rledford/tmux-diff-peek'
```

Then press `prefix + I` to install.

### Manual

Clone the repository and run the registration script:

```sh
git clone https://github.com/rledford/tmux-diff-peek ~/.tmux/plugins/tmux-diff-peek
~/.tmux/plugins/tmux-diff-peek/diff-peek.tmux
```

## Default Keybindings

| Keybinding | Action |
|---|---|
| `<prefix>-g` | Show unstaged and untracked diff for current pane's git context |
| `<prefix>-G` | Show staged diff for current pane's git context |

## Configuration

All options are set in `~/.tmux.conf`.

### `@diff-peek-key`

The key used to trigger the unstaged/untracked diff popup. Default: `g`

```tmux
set -g @diff-peek-key 'g'
```

### `@diff-peek-staged-key`

The key used to trigger the staged diff popup. Default: `G`

```tmux
set -g @diff-peek-staged-key 'G'
```

### `@diff-peek-width`

The width of the popup as a percentage of the terminal width. Default: `80%`

```tmux
set -g @diff-peek-width '80%'
```

### `@diff-peek-height`

The height of the popup as a percentage of the terminal height. Default: `80%`

```tmux
set -g @diff-peek-height '80%'
```

### `@diff-peek-clipboard-command`

The command used to write exported comments to the system clipboard. Default: `pbcopy` (macOS).

```tmux
set -g @diff-peek-clipboard-command 'pbcopy'
```

The value is split on whitespace and passed as an argv list to `vim.fn.system`, so simple flag arguments are supported (e.g., `xclip -selection clipboard`). Shell-style quoting of arguments containing spaces is not supported.

### `@diff-peek-export-key`

The neovim mapping used to trigger export from the comments buffer. Default: `<leader>x` (the plugin sets its own leader to `<Space>`, so the default key is `<Space>x`).

```tmux
set -g @diff-peek-export-key '<leader>x'
```

## Status Bar Git Info

The plugin automatically updates a per-pane tmux variable `@git_status` whenever you switch panes. This variable contains the current branch name along with counts for modified, staged, and untracked files — omitting any category with a count of zero.

Example values:

```
main
main ●2
main ●2 +1 ?3
```

Where `●` = modified, `+` = staged, `?` = untracked.

To display it in your status bar, add `#{@git_status}` to `status-right` in `~/.tmux.conf`. For a periodic refresh between pane switches, also include a `#()` call to the script:

```tmux
set -g status-right "#(~/.tmux/plugins/tmux-diff-peek/scripts/git_status.sh #{pane_id} #{pane_current_path})#[fg=colour141]#{@git_status}"
set -g status-interval 10
```

The `#()` call produces no output — it runs as a side effect to keep `@git_status` current while you work in a single pane.

## Agent CWD Hook

When a long-running agent is launched in a tmux pane and then switches to a different working directory internally (e.g., into a worktree), the pane's `#{pane_current_path}` still reflects the shell's launch directory. To follow the agent's actual working directory, configure the agent to invoke the bundled hook script whenever its cwd could have changed.

The hook script is at `scripts/cwd_hook.sh`. It reads a JSON payload on stdin, extracts the `cwd` field, and writes it to `~/.cache/tmux-diff-peek/<pane_id>.cwd` keyed by the `$TMUX_PANE` environment variable tmux sets on every child process. The plugin reads that file and falls back to `#{pane_current_path}` when it's absent or stale. The hook is a no-op outside tmux.

### Claude Code

Add the hook to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.tmux/plugins/tmux-diff-peek/scripts/cwd_hook.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.tmux/plugins/tmux-diff-peek/scripts/cwd_hook.sh"
          }
        ]
      }
    ]
  }
}
```

Adjust the path if the plugin lives elsewhere.

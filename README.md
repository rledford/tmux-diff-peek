# tmux-diff-peek

A tmux plugin that shows git diffs in a popup overlay without leaving your current workflow.

## What It Does

`tmux-diff-peek` provides two keybindings for viewing git diffs in a floating popup window:

- `<prefix>-g` — Opens a popup showing unstaged changes for the current pane's git context. The plugin uses smart process-tree detection to determine the relevant working directory based on what is running in the active pane.
- `<prefix>-G` — Prompts for a path, then opens a popup showing `git diff <path>`.

## Requirements

- tmux >= 3.2

## Installation

### Via TPM (Tmux Plugin Manager)

Add the following to your `~/.tmux.conf`:

```tmux
set -g @plugin 'user/tmux-diff-peek'
```

Then press `prefix + I` to install.

### Manual

Clone the repository and run the registration script:

```sh
git clone https://github.com/user/tmux-diff-peek ~/.tmux/plugins/tmux-diff-peek
~/.tmux/plugins/tmux-diff-peek/diff-peek.tmux
```

## Default Keybindings

| Keybinding | Action |
|---|---|
| `<prefix>-g` | Show unstaged diff for current pane's git context |
| `<prefix>-G` | Prompt for a path, then show `git diff <path>` |

## Configuration

All options are set in `~/.tmux.conf`.

### `@diff-peek-key`

The key used to trigger the smart-context diff popup. Default: `g`

```tmux
set -g @diff-peek-key 'g'
```

### `@diff-peek-path-key`

The key used to trigger the path-prompted diff popup. Default: `G`

```tmux
set -g @diff-peek-path-key 'G'
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

## Pager Support

The diff viewer respects git's `core.pager` setting. Configure your preferred pager in your git config and it will be used automatically:

```sh
git config --global core.pager delta
```

Any pager that works with `git diff` (e.g., `delta`, `diff-so-fancy`) will work inside the popup.

## AI Agent Usage

The plugin works identically for AI agents (e.g., Claude Code). Agents can invoke the diff popup via the normal keybinding or call the scripts directly:

```sh
tmux run-shell '$PLUGIN_DIR/scripts/diff_peek.sh'
```

```sh
tmux run-shell '$PLUGIN_DIR/scripts/diff_peek_path.sh "/path/to/repo"'
```

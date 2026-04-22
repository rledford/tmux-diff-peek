#!/usr/bin/env sh

_vars="$(dirname "$0")/variables.sh"
[ -f "$_vars" ] && . "$_vars"
unset _vars

get_tmux_option() {
  result="$(tmux show-option -gqv "$1")"
  if [ -z "$result" ]; then
    echo "$2"
  else
    echo "$result"
  fi
  return 0
}

resolve_path() {
  raw_input="$1"
  pane_current_path="$2"

  case "$raw_input" in
    \~*)
      resolved="$HOME${raw_input#\~}"
      ;;
    *)
      resolved="$raw_input"
      ;;
  esac

  case "$resolved" in
    /*)
      ;;
    *)
      resolved="$pane_current_path/$resolved"
      ;;
  esac

  echo "$resolved"
  return 0
}

check_git_repo() {
  if ! git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; then
    _saved_style="$(tmux show -gv message-style 2>/dev/null)"
    tmux set -g message-style "fg=yellow"
    tmux display-message "diff-peek: not a git repository"
    tmux set -g message-style "${_saved_style:-default}"
    return 1
  fi
  return 0
}

has_diff() {
  path="$1"
  file_arg="$2"
  git -C "$path" diff --quiet $file_arg 2>/dev/null
  return $?
}

has_untracked() {
  [ -n "$(git -C "$1" ls-files --others --exclude-standard 2>/dev/null)" ]
}

has_staged() {
  git -C "$1" diff --cached --quiet 2>/dev/null
  return $?
}

_diff_peek_cache_dir() {
  echo "$HOME/.cache/tmux-diff-peek"
}

resolve_git_cwd() {
  pane_id="$1"
  fallback="$2"

  if [ -n "$pane_id" ]; then
    cache_file="$(_diff_peek_cache_dir)/${pane_id#%}.cwd"
    if [ -r "$cache_file" ]; then
      cwd="$(cat "$cache_file" 2>/dev/null)"
      if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "$cwd"
        return 0
      fi
    fi
  fi

  echo "$fallback"
}

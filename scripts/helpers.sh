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

_collect_pids() {
  echo "$1"
  for child in $(pgrep -P "$1" 2>/dev/null); do
    _collect_pids "$child"
  done
}

_get_proc_cwd() {
  if [ -L /proc/"$1"/cwd ]; then
    readlink /proc/"$1"/cwd 2>/dev/null
  else
    lsof -p "$1" -a -d cwd -Fn 2>/dev/null | awk '/^n/{print substr($0,2)}'
  fi
}

resolve_git_cwd() {
  pane_pid="$1"
  fallback="$2"
  best=""

  for pid in $(_collect_pids "$pane_pid"); do
    cwd="$(_get_proc_cwd "$pid")"
    [ -z "$cwd" ] && continue
    if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if [ "${#cwd}" -gt "${#best}" ]; then
        best="$cwd"
      fi
    fi
  done

  if [ -z "$best" ]; then
    echo "$fallback"
  else
    echo "$best"
  fi
}

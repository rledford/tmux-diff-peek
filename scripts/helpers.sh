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

_is_claude_pid() {
  name="$(ps -p "$1" -o comm= 2>/dev/null)"
  [ -z "$name" ] && return 1
  case "${name##*/}" in
    claude) return 0 ;;
    *) return 1 ;;
  esac
}

_claude_session_uuids() {
  lsof -p "$1" 2>/dev/null | awk '
    {
      for (i = 9; i <= NF; i++) {
        if ($i ~ /\/\.claude\/tasks\/[0-9a-f-]+$/) {
          n = split($i, parts, "/")
          print parts[n]
        }
      }
    }
  '
}

_find_session_jsonl() {
  for f in "$HOME"/.claude/projects/*/"$1".jsonl; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

_file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

_latest_cwd_in_jsonl() {
  tail -c 65536 "$1" 2>/dev/null | tr ',' '\n' | grep '"cwd":"' | tail -1 | sed 's/.*"cwd":"//; s/".*//'
}

_get_claude_cwd() {
  pid="$1"
  best_mtime=0
  best_cwd=""
  for uuid in $(_claude_session_uuids "$pid"); do
    jsonl="$(_find_session_jsonl "$uuid")" || continue
    [ -z "$jsonl" ] && continue
    mtime="$(_file_mtime "$jsonl")"
    [ -z "$mtime" ] && continue
    if [ "$mtime" -gt "$best_mtime" ]; then
      cwd="$(_latest_cwd_in_jsonl "$jsonl")"
      if [ -n "$cwd" ]; then
        best_mtime="$mtime"
        best_cwd="$cwd"
      fi
    fi
  done
  echo "$best_cwd"
}

resolve_git_cwd() {
  pane_pid="$1"
  fallback="$2"
  best=""

  for pid in $(_collect_pids "$pane_pid"); do
    cwd=""
    if _is_claude_pid "$pid"; then
      cwd="$(_get_claude_cwd "$pid")"
    fi
    [ -z "$cwd" ] && cwd="$(_get_proc_cwd "$pid")"
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

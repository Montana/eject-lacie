#!/usr/bin/env bash

# by michael mendy (c) 2025.

set -euo pipefail

vol_input=""
kill_blockers=0
use_force=0
pause_spotlight=0
dry_run=0
quiet=0
retries=1

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "missing required command: $1" >&2; exit 1; }; }

print_help() {
  cat <<'EOF'
Examples:
#   ./eject_lacie.sh                    # auto-detect /Volumes/LaCie*
#   ./eject_lacie.sh -v "LaCie" -k -f   # target by name; kill blockers; force if needed
#   ./eject_lacie.sh -v /Volumes/LaCie -k -s
EOF
}

log() {
  [ "$quiet" -eq 1 ] && return 0
  printf '%s\n' "$*"
}

while getopts ":v:kfshnr:q" opt; do
  case "$opt" in
    v) vol_input="$OPTARG" ;;
    k) kill_blockers=1 ;;
    f) use_force=1 ;;
    s) pause_spotlight=1 ;;
    n) dry_run=1 ;;
    r) retries="$OPTARG" ;;
    q) quiet=1 ;;
    h) print_help; exit 0 ;;
    \?) echo "invalid option: -$OPTARG" >&2; print_help; exit 2 ;;
    :) echo "option -$OPTARG requires an argument." >&2; exit 2 ;;
  esac
done

for arg in "$@"; do
  if [ "$arg" = "--help" ]; then
    print_help
    exit 0
  fi
done

need_cmd diskutil
need_cmd lsof
need_cmd awk
need_cmd grep
need_cmd df

resolve_volume_mount() {
  local input mount
  input="${1:-}"
  mount=""

  if [ -z "$input" ]; then
    mount=$(ls -d /Volumes/LaCie* 2>/dev/null | head -n 1 || true)
    if [ -z "$mount" ]; then
      mount=$(mount | awk '/\/Volumes\/.*LaCie/ {print $3; exit}')
    fi
  elif [ -d "$input" ]; then
    mount="$input"
  else
    mount="/Volumes/$input"
  fi

  if [ -z "$mount" ] || [ ! -d "$mount" ]; then
    return 1
  fi

  (cd "$mount" && pwd)
}

get_device_from_mount() {
  mount | grep " on $1 " | awk '{print $1}'
}

spotlight_disable() {
  if command -v mdutil >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ]; then
      log "[dry-run] would disable spotlight on $1"
    else
      mdutil -i off "$1" >/dev/null 2>&1 || true
    fi
  fi
}

spotlight_enable() {
  if command -v mdutil >/dev/null 2>&1; then
    if [ "$dry_run" -eq 1 ]; then
      log "[dry-run] would re-enable spotlight on $1"
    else
      mdutil -i on "$1" >/dev/null 2>&1 || true
    fi
  fi
}

show_blockers() {
  if ! sudo -n true 2>/dev/null; then
    log "note: not running with sudo; lsof may miss some processes."
  fi
  sudo lsof +f -- "$1" || true
}

kill_blockers() {
  local pids
  pids=$(sudo lsof -t +f -- "$1" | sort -u || true)
  [ -z "$pids" ] && return 0

  if [ "$dry_run" -eq 1 ]; then
    log "[dry-run] would send sigterm to pids: $pids"
    log "[dry-run] would send sigkill to remaining pids if needed"
    return 0
  fi

  sudo kill -15 $pids 2>/dev/null || true
  sleep 2
  pids=$(sudo lsof -t +f -- "$1" | sort -u || true)
  [ -z "$pids" ] && return 0
  sudo kill -9 $pids 2>/dev/null || true
  sleep 1
}

unmount_try() {
  if [ "$dry_run" -eq 1 ]; then
    log "[dry-run] would run: diskutil unmount \"$1\""
    return 0
  fi
  diskutil unmount "$1"
}

unmount_force_try() {
  if [ "$dry_run" -eq 1 ]; then
    log "[dry-run] would run: diskutil unmount force \"$1\""
    return 0
  fi
  diskutil unmount force "$1"
}

eject_device() {
  [ -z "${1:-}" ] && return 1
  if [ "$dry_run" -eq 1 ]; then
    log "[dry-run] would run: diskutil eject \"$1\""
    return 0
  fi
  diskutil eject "$1"
}

show_volume_info() {
  local mount_path="$1"
  log "volume info for $mount_path:"
  df -h "$mount_path" | awk 'NR==1 || NR==2 {print "  "$0}'
}

main() {
  local mount_path devnode attempt

  if ! mount_path=$(resolve_volume_mount "$vol_input"); then
    echo "could not find a lacie volume. try -v 'LaCie' or -v /Volumes/LaCie" >&2
    exit 1
  fi

  devnode=$(get_device_from_mount "$mount_path" || true)

  log "target mount: $mount_path"
  [ -n "$devnode" ] && log "device node: $devnode"

  show_volume_info "$mount_path"

  [ "$pause_spotlight" -eq 1 ] && spotlight_disable "$mount_path"

  log "checking for open files on $mount_path..."
  show_blockers "$mount_path"

  if ! unmount_try "$mount_path"; then
    if [ "$kill_blockers" -eq 1 ]; then
      log "unmount failed, attempting to kill blockers..."
      kill_blockers "$mount_path"
    fi
    if [ "$use_force" -eq 1 ]; then
      log "attempting force unmount..."
      unmount_force_try "$mount_path" || {
        [ "$pause_spotlight" -eq 1 ] && spotlight_enable "$mount_path"
        exit 1
      }
    else
      echo "normal unmount failed. re-run with -f to force and/or -k to kill blockers." >&2
      [ "$pause_spotlight" -eq 1 ] && spotlight_enable "$mount_path"
      exit 2
    fi
  fi

  attempt=1
  while :; do
    if eject_device "$devnode"; then
      break
    fi

    if [ "$attempt" -ge "$retries" ]; then
      echo "eject failed after $retries attempt(s). ensure no background services are re-mounting it (time machine, backups, media indexers)." >&2
      [ "$pause_spotlight" -eq 1 ] && spotlight_enable "$mount_path"
      exit 3
    fi

    log "eject failed (attempt $attempt), retrying..."
    attempt=$((attempt + 1))
    sleep 1
  done

  [ "$pause_spotlight" -eq 1 ] && spotlight_enable "$mount_path"
  log "done."
}

main "$@"

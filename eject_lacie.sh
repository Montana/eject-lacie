#!/usr/bin/env bash

# by michael mendy (c) 2025. 

set -euo pipefail

VOL_INPUT=""
KILL_BLOCKERS=0
USE_FORCE=0
PAUSE_SPOTLIGHT=0

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

print_help() {
  cat <<'EOF'
Examples:
#   ./eject_lacie.sh                    # auto-detect /Volumes/LaCie*
#   ./eject_lacie.sh -v "LaCie" -k -f   # target by name; kill blockers; force if needed
#   ./eject_lacie.sh -v /Volumes/LaCie -k -s
EOF
}

while getopts ":v:kfsh" opt; do
  case "$opt" in
    v) VOL_INPUT="$OPTARG" ;;
    k) KILL_BLOCKERS=1 ;;
    f) USE_FORCE=1 ;;
    s) PAUSE_SPOTLIGHT=1 ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; print_help; exit 2 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 2 ;;
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
    mdutil -i off "$1" >/dev/null 2>&1 || true
  fi
}

spotlight_enable() {
  if command -v mdutil >/dev/null 2>&1; then
    mdutil -i on "$1" >/dev/null 2>&1 || true
  fi
}

show_blockers() {
  if ! sudo -n true 2>/dev/null; then
    echo "Note: not running with sudo; lsof may miss some processes."
  fi
  sudo lsof +f -- "$1" || true
}

kill_blockers() {
  local pids
  pids=$(sudo lsof -t +f -- "$1" | sort -u || true)
  [ -z "$pids" ] && return 0
  sudo kill -15 $pids 2>/dev/null || true
  sleep 2
  pids=$(sudo lsof -t +f -- "$1" | sort -u || true)
  [ -z "$pids" ] && return 0
  sudo kill -9 $pids 2>/dev/null || true
  sleep 1
}

unmount_try() {
  diskutil unmount "$1"
}

unmount_force_try() {
  diskutil unmount force "$1"
}

eject_device() {
  [ -z "${1:-}" ] && return 1
  diskutil eject "$1"
}

main() {
  local mount_path devnode

  if ! mount_path=$(resolve_volume_mount "$VOL_INPUT"); then
    echo "Could not find a LaCie volume. Try -v 'LaCie' or -v /Volumes/LaCie" >&2
    exit 1
  fi

  devnode=$(get_device_from_mount "$mount_path" || true)

  [ "$PAUSE_SPOTLIGHT" -eq 1 ] && spotlight_disable "$mount_path"

  show_blockers "$mount_path"

  if ! unmount_try "$mount_path"; then
    if [ "$KILL_BLOCKERS" -eq 1 ]; then
      kill_blockers "$mount_path"
    fi
    if [ "$USE_FORCE" -eq 1 ]; then
      unmount_force_try "$mount_path" || {
        [ "$PAUSE_SPOTLIGHT" -eq 1 ] && spotlight_enable "$mount_path"
        exit 1
      }
    else
      echo "Normal unmount failed. Re-run with -f to force and/or -k to kill blockers." >&2
      [ "$PAUSE_SPOTLIGHT" -eq 1 ] && spotlight_enable "$mount_path"
      exit 2
    fi
  fi

  if ! eject_device "$devnode"; then
    echo "Eject failed. Ensure no background services are re-mounting it (Time Machine, backups, media indexers)." >&2
    [ "$PAUSE_SPOTLIGHT" -eq 1 ] && spotlight_enable "$mount_path"
    exit 3
  fi

  [ "$PAUSE_SPOTLIGHT" -eq 1 ] && spotlight_enable "$mount_path"
  echo "Done."
}

main "$@"

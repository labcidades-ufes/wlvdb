#!/usr/bin/env bash
# Linux/bash counterpart of scripts/run-experiment.ps1; keep both in sync.
# Creates a campaign, redirects process temporaries into it, runs the command
# with console capture, and registers completion or failure.
#
# Usage:
#   run-experiment.sh -Id <id> -Executable <command> [-Purpose <text>]
#                     [-Preserve] [-- <arguments...>]

set -o pipefail
LC_ALL=C
export LC_ALL

usage() {
  cat >&2 <<'EOF'
Usage: run-experiment.sh -Id <id> -Executable <command>
                         [-Purpose <text>] [-Preserve] [-- <arguments...>]
EOF
}

manager=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/manage-campaigns.sh
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1

ID=''
EXECUTABLE=''
PURPOSE=''
PRESERVE=false
while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      break
      ;;
    -Id | -Executable | -Purpose)
      if [ $# -lt 2 ]; then
        printf 'Missing value for %s\n' "$1" >&2
        usage
        exit 2
      fi
      case "$1" in
        -Id) ID=$2 ;;
        -Executable) EXECUTABLE=$2 ;;
        -Purpose) PURPOSE=$2 ;;
      esac
      shift 2
      ;;
    -Id=*) ID=${1#-Id=}; shift ;;
    -Executable=*) EXECUTABLE=${1#-Executable=}; shift ;;
    -Purpose=*) PURPOSE=${1#-Purpose=}; shift ;;
    -Preserve) PRESERVE=true; shift ;;
    -Preserve=true) PRESERVE=true; shift ;;
    -Preserve=false) PRESERVE=false; shift ;;
    -*)
      printf 'Unrecognized argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$ID" ] || ! [[ "$ID" =~ ^[a-z0-9][a-z0-9_-]{0,79}$ ]]; then
  printf 'Invalid or missing -Id: it must match ^[a-z0-9][a-z0-9_-]{0,79}\$.\n' >&2
  exit 2
fi
if [ -z "$EXECUTABLE" ]; then
  printf -- '-Executable is required.\n' >&2
  exit 2
fi
command_path=$(command -v -- "$EXECUTABLE")
if [ $? -ne 0 ] || [ -z "$command_path" ] || [ ! -x "$command_path" ]; then
  printf 'Cannot find the executable: %s\n' "$EXECUTABLE" >&2
  exit 1
fi

manager_args=(-Action New -Id "$ID")
if [ -n "$PURPOSE" ]; then
  manager_args+=(-Purpose "$PURPOSE")
fi
if [ "$PRESERVE" = true ]; then
  manager_args+=(-Preserve)
fi
campaign=$(bash "$manager" "${manager_args[@]}") || exit 1
root=$(printf '%s\n' "$campaign" | sed -n 's/^root=//p')
scratch=$(printf '%s\n' "$campaign" | sed -n 's/^temporary_directory=//p')
if [ -z "$root" ] || [ -z "$scratch" ]; then
  printf 'Unexpected campaign creation output.\n' >&2
  exit 1
fi

environment_names=(TEMP TMP TMPDIR WLV_CAMPAIGN_ROOT PYTHONUTF8 PYTHONIOENCODING)
declare -A saved_values=()
declare -A saved_present=()
restore_environment() {
  local name
  for name in "${environment_names[@]}"; do
    if [ "${saved_present[$name]+set}" = 'set' ]; then
      export "$name=${saved_values[$name]}"
    else
      unset "$name"
    fi
  done
}
trap restore_environment EXIT

for name in "${environment_names[@]}"; do
  if [[ -v "$name" ]]; then
    saved_values["$name"]="${!name}"
    saved_present["$name"]=1
  fi
done

fail_campaign() {
  bash "$manager" -Action Fail -Id "$ID" >/dev/null 2>&1
}

export TEMP="$scratch"
export TMP="$scratch"
export TMPDIR="$scratch"
export WLV_CAMPAIGN_ROOT="$root"
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

if ! cd "$repo"; then
  printf 'Cannot enter the repository directory: %s\n' "$repo" >&2
  fail_campaign
  exit 1
fi

log="$root/logs/console.log"
exit_code=0
"$command_path" "$@" 2>&1 | tee "$log"
exit_code=${PIPESTATUS[0]}
if [ "$exit_code" -ne 0 ]; then
  printf 'Experiment exited with code %s. See %s\n' "$exit_code" "$log" >&2
  fail_campaign
  exit 1
fi

if ! bash "$manager" -Action Complete -Id "$ID" >/dev/null; then
  fail_campaign
  exit 1
fi

printf 'Experiment completed: %s. Review retained outputs, then run scripts/manage-campaigns.sh -Action Clean.\n' "$root"

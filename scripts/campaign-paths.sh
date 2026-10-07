#!/usr/bin/env bash
# Shared output boundary for manual campaign tools. Read-only inputs may live
# elsewhere. Linux/bash counterpart of scripts/campaign-paths.ps1; keep both
# in sync. This file only defines functions so it can be sourced safely.

wlv_lexical_full_path() {
  # Resolve a path lexically against the current directory without touching
  # the filesystem (closest match to [IO.Path]::GetFullPath semantics).
  local input="$1" anchor cleaned part joined=''
  local -a parts=() stack=()
  if [[ "$input" == /* ]]; then
    anchor='/'
    cleaned="${input#/}"
  else
    anchor="$PWD/"
    cleaned="$input"
  fi
  while [[ "$cleaned" == /* ]]; do cleaned="${cleaned#/}"; done
  IFS='/' read -r -a parts <<<"$cleaned"
  for part in "${parts[@]}"; do
    case "$part" in
      '' | .) ;;
      ..)
        if [ "${#stack[@]}" -gt 0 ]; then
          unset 'stack[$(( ${#stack[@]} - 1 ))]'
        fi
        ;;
      *)
        stack+=("$part")
        ;;
    esac
  done
  if [ "${#stack[@]}" -gt 0 ]; then
    local IFS='/'
    joined="${stack[*]}"
  fi
  printf '%s%s' "$anchor" "$joined"
}

wlv_valid_campaign_id() {
  # Same rule as the ValidatePattern in the PowerShell tools.
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]{0,79}$ ]]
}

assert_wlv_campaign_output_path() {
  if [ "$#" -ne 1 ]; then
    printf 'assert_wlv_campaign_output_path requires exactly one path argument.\n' >&2
    return 1
  fi
  local script_dir repository common main temporary full prefix relative id cursor manifest
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  repository=$(cd -- "$script_dir/.." && pwd -P) || return 1
  common=$(git -C "$repository" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ -z "$common" ]; then
    printf 'Cannot locate the main repository for campaign storage.\n' >&2
    return 1
  fi
  common=$(wlv_lexical_full_path "$common")
  main=$(dirname -- "$common")
  temporary="$main/temp"
  full=$(wlv_lexical_full_path "$1")
  prefix="$temporary/"
  case "$full" in
    "$prefix"*) ;;
    *)
      printf 'Campaign outputs must be inside the main repository temp/<id>/ directory.\n' >&2
      return 1
      ;;
  esac
  relative="${full#"$prefix"}"
  id="${relative%%/*}"
  if ! wlv_valid_campaign_id "$id" || [ "$id" = '054' ]; then
    printf 'Invalid or preserved campaign output target.\n' >&2
    return 1
  fi
  cursor="$full"
  while [ -n "$cursor" ]; do
    if [ -L "$cursor" ]; then
      printf 'Campaign output has a linked ancestor: %s\n' "$cursor" >&2
      return 1
    fi
    cursor="${cursor%/*}"
  done
  manifest="$temporary/$id/.campaign.json"
  if [ ! -f "$manifest" ]; then
    printf 'Create a registered campaign first with scripts/manage-campaigns.sh -Action New.\n' >&2
    return 1
  fi
  if [ -L "$manifest" ]; then
    printf 'Linked campaign manifest is not allowed.\n' >&2
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python 3 is required to read the campaign manifest.\n' >&2
    return 1
  fi
  if ! python3 - "$manifest" "$id" <<'PY'
import json
import sys

manifest, expected = sys.argv[1], sys.argv[2]
try:
    with open(manifest, 'r', encoding='utf-8-sig') as handle:
        data = json.load(handle)
except Exception:
    sys.exit(1)
valid = (isinstance(data, dict)
         and data.get('schema') == 'wlv-campaign/1'
         and data.get('id') == expected
         and data.get('status') == 'active')
sys.exit(0 if valid else 1)
PY
  then
    printf 'Campaign output requires an active campaign manifest.\n' >&2
    return 1
  fi
  printf '%s\n' "$full"
}

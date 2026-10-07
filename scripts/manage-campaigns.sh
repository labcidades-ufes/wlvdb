#!/usr/bin/env bash
# Linux/bash counterpart of scripts/manage-campaigns.ps1; keep both in sync.
# Manages local experiment campaigns under temp/<id>/ inside this repository.
# Manifests are UTF-8 JSON compatible with the PowerShell tools in both
# directions, so the same temp/ tree is usable from Windows and Linux.

set -o pipefail
LC_ALL=C
export LC_ALL

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
tempRoot="$repo/temp"

usage() {
  cat >&2 <<'EOF'
Usage: manage-campaigns.sh -Action <New|Status|Complete|Fail|Clean>
                           [-Id <id>] [-Purpose <text>] [-Preserve] [-Apply]
EOF
}

ACTION=''
ID=''
PURPOSE=''
PRESERVE=false
APPLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    -Action | -Id | -Purpose)
      if [ $# -lt 2 ]; then
        printf 'Missing value for %s\n' "$1" >&2
        usage
        exit 2
      fi
      case "$1" in
        -Action) ACTION=$2 ;;
        -Id) ID=$2 ;;
        -Purpose) PURPOSE=$2 ;;
      esac
      shift 2
      ;;
    -Action=*) ACTION=${1#-Action=}; shift ;;
    -Id=*) ID=${1#-Id=}; shift ;;
    -Purpose=*) PURPOSE=${1#-Purpose=}; shift ;;
    -Preserve) PRESERVE=true; shift ;;
    -Preserve=true) PRESERVE=true; shift ;;
    -Preserve=false) PRESERVE=false; shift ;;
    -Apply) APPLY=true; shift ;;
    -Apply=true) APPLY=true; shift ;;
    -Apply=false) APPLY=false; shift ;;
    *)
      printf 'Unrecognized argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$ACTION" in
  New | Status | Complete | Fail | Clean) ;;
  *)
    printf "Invalid -Action '%s': expected New, Status, Complete, Fail or Clean.\n" "$ACTION" >&2
    usage
    exit 2
    ;;
esac

if [ -n "$ID" ] && ! [[ "$ID" =~ ^[a-z0-9][a-z0-9_-]{0,79}$ ]]; then
  printf "Invalid -Id '%s': must match ^[a-z0-9][a-z0-9_-]{0,79}\$.\n" "$ID" >&2
  exit 2
fi

if [ "$ACTION" != 'Status' ] && [ "$ACTION" != 'Clean' ] && [ -z "$ID" ]; then
  printf -- '-Id is required for this action.\n' >&2
  exit 1
fi

if [ "$APPLY" = true ] && [ "$ACTION" != 'Clean' ]; then
  printf -- '-Apply is only valid with Clean.\n' >&2
  exit 1
fi

if [ "$PRESERVE" = true ]; then
  case "$ACTION" in
    New | Complete | Fail) ;;
    *)
      printf -- '-Preserve is only valid with New, Complete or Fail.\n' >&2
      exit 1
      ;;
  esac
fi

command -v python3 >/dev/null 2>&1 || {
  printf 'Python 3 is required to manage campaign manifests.\n' >&2
  exit 1
}

wlv_trim_trailing_slashes() {
  local value="$1"
  while [ "$value" != '/' ] && [[ "$value" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "$value"
}

wlv_assert_real_ancestors() {
  local cursor
  cursor=$(wlv_trim_trailing_slashes "$1")
  while [ -n "$cursor" ]; do
    if [ -L "$cursor" ]; then
      printf 'Linked path is not allowed: %s\n' "$cursor" >&2
      return 1
    fi
    cursor="${cursor%/*}"
  done
  return 0
}

wlv_assert_campaign_path() {
  local full
  full=$(wlv_trim_trailing_slashes "$1")
  if [ "$(dirname -- "$full")" != "$tempRoot" ]; then
    printf 'A campaign must be a direct child of this repository temp directory.\n' >&2
    return 1
  fi
  wlv_assert_real_ancestors "$full" || return 1
  printf '%s\n' "$full"
}

# Prints validated manifest fields as key=value lines. Exit codes:
#   0 valid, 2 unreadable/undecodable, 3 schema-invalid.
wlv_python_read_manifest() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

manifest, expected_id = sys.argv[1], sys.argv[2]
try:
    with open(manifest, 'r', encoding='utf-8-sig') as handle:
        data = json.load(handle)
except Exception:
    sys.exit(2)
valid = (isinstance(data, dict)
         and data.get('schema') == 'wlv-campaign/1'
         and data.get('id') == expected_id
         and data.get('status') in ('active', 'completed', 'failed', 'archived')
         and isinstance(data.get('preserve'), bool))
if not valid:
    sys.exit(3)

def esc(value):
    return str(value).replace('\\', '\\\\').replace('\n', '\\n')

print('schema=' + esc(data.get('schema', '')))
print('id=' + esc(data.get('id', '')))
print('purpose=' + esc(data.get('purpose', '')))
print('commit=' + esc(data.get('commit', '')))
print('status=' + esc(data.get('status', '')))
print('preserve=' + ('true' if data['preserve'] else 'false'))
print('created_at_utc=' + esc(data.get('created_at_utc', '')))
if 'closed_at_utc' in data:
    print('closed_at_utc=' + esc(data['closed_at_utc']))
PY
}

wlv_read_campaign() {
  local path="$1" manifest fields status_code
  path=$(wlv_assert_campaign_path "$path") || return 1
  manifest="$path/.campaign.json"
  if [ ! -f "$manifest" ]; then
    printf 'Unknown directory, missing campaign manifest: %s\n' "$path" >&2
    return 1
  fi
  wlv_assert_real_ancestors "$manifest" || return 1
  fields=$(wlv_python_read_manifest "$manifest" "$(basename -- "$path")")
  status_code=$?
  case "$status_code" in
    0) ;;
    2)
      printf 'Cannot read campaign manifest: %s\n' "$manifest" >&2
      return 1
      ;;
    *)
      printf 'Invalid campaign manifest: %s\n' "$manifest" >&2
      return 1
      ;;
  esac
  printf '%s\n' "$fields"
}

wlv_field() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p"
}

wlv_write_campaign() {
  local path="$1" cid="$2" purpose="$3" commit="$4" status="$5" preserve="$6" created="$7" closed="${8:-}"
  local manifest="$path/.campaign.json"
  wlv_assert_real_ancestors "$manifest" || return 1
  if ! python3 - "$manifest" "$cid" "$purpose" "$commit" "$status" "$preserve" "$created" "$closed" <<'PY'
import json
import sys

manifest, cid, purpose, commit, status, preserve, created, closed = sys.argv[1:9]
record = {
    'schema': 'wlv-campaign/1',
    'id': cid,
    'purpose': purpose,
    'commit': commit,
    'status': status,
    'preserve': preserve == 'true',
    'created_at_utc': created,
}
if closed:
    record['closed_at_utc'] = closed
text = json.dumps(record, ensure_ascii=False, indent=2) + '\n'
with open(manifest, 'w', encoding='utf-8', newline='\n') as handle:
    handle.write(text)
with open(manifest, 'r', encoding='utf-8') as handle:
    if handle.read() != text:
        sys.exit(1)
PY
  then
    printf 'Campaign manifest failed its UTF-8 round trip.\n' >&2
    return 1
  fi
}

wlv_get_worktrees() {
  local output line
  if ! output=$(git -C "$repo" worktree list --porcelain); then
    printf 'Cannot inspect registered Git worktrees.\n' >&2
    return 1
  fi
  while IFS= read -r line; do
    case "$line" in
      'worktree '*)
        line=$(wlv_trim_trailing_slashes "${line#'worktree '}")
        printf '%s\n' "$line"
        ;;
    esac
  done <<<"$output"
}

wlv_path_within() {
  [ "$1" = "$2" ] && return 0
  case "$1" in
    "$2"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Preflight every removable campaign. Inputs: $1 path, $WLV_WORKTREES the
# registered worktree list. Outputs: REMOVABLE_ID, REMOVABLE_PATH,
# REMOVABLE_BYTES and the array REMOVABLE_WORKTREES.
wlv_assert_removable_campaign() {
  local path="$1" record id preserve status links lockscan pid cmdline
  local -a children=()
  record=$(wlv_read_campaign "$path") || return 1
  id=$(wlv_field "$record" id)
  preserve=$(wlv_field "$record" preserve)
  status=$(wlv_field "$record" status)
  if [ "$id" = '054' ] || [ "$preserve" = 'true' ] ||
    { [ "$status" != 'completed' ] && [ "$status" != 'failed' ]; }; then
    printf 'Campaign is active or preserved: %s\n' "$path" >&2
    return 1
  fi
  links=$(find "$path" -type l -print 2>/dev/null)
  if [ $? -ne 0 ]; then
    printf 'Cannot inspect campaign contents: %s\n' "$path" >&2
    return 1
  fi
  if [ -n "$links" ]; then
    printf 'Campaign contains a link or junction: %s\n' "$path" >&2
    return 1
  fi
  lockscan=$(find "$path" -regextype posix-extended \
    -regex '.*/(\.running\.lock|\.lock[^/]*|\.issue13[^/]*lock)$' -print 2>/dev/null)
  if [ $? -ne 0 ]; then
    printf 'Cannot inspect campaign contents: %s\n' "$path" >&2
    return 1
  fi
  if [ -n "$lockscan" ]; then
    printf 'Campaign contains a process/result lock: %s\n' "$path" >&2
    return 1
  fi
  # A running process explicitly pointing at this campaign prevents removal.
  # Failure to query processes is an error, not permission to delete.
  if [ ! -d /proc ]; then
    printf 'Cannot inspect running processes.\n' >&2
    return 1
  fi
  for pid in /proc/[0-9]*; do
    case "${pid#/proc/}" in
      "$$") continue ;;
    esac
    [ -r "$pid/cmdline" ] || continue
    cmdline=$(tr '\0' ' ' <"$pid/cmdline" 2>/dev/null) || continue
    if [ -n "$cmdline" ] && [[ "$cmdline" == *"$path"* ]]; then
      printf 'A running process references this campaign: %s\n' "$path" >&2
      return 1
    fi
  done
  local wt
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    if wlv_path_within "$wt" "$path"; then
      children+=("$wt")
    fi
  done <<<"$WLV_WORKTREES"
  # Unknown nested repositories are preserved, never erased as loose files.
  local gitdir parent registered status_output
  while IFS= read -r gitdir; do
    [ -n "$gitdir" ] || continue
    parent=$(dirname -- "$gitdir")
    registered=false
    for wt in "${children[@]}"; do
      if [ "$wt" = "$parent" ]; then
        registered=true
        break
      fi
    done
    if [ "$registered" != true ]; then
      printf 'Unregistered repository in campaign: %s\n' "$gitdir" >&2
      return 1
    fi
  done < <(find "$path" -name .git -print 2>/dev/null)
  for wt in "${children[@]}"; do
    if ! status_output=$(git -c core.longpaths=true -C "$wt" status --porcelain=v1 --untracked-files=all) ||
      [ -n "$status_output" ]; then
      printf 'Preserve local code changes before cleaning worktree: %s\n' "$wt" >&2
      return 1
    fi
  done
  REMOVABLE_BYTES=$(find "$path" -type f -printf '%s\n' 2>/dev/null |
    awk '{ total += $1 } END { printf "%.0f\n", total + 0 }')
  if [ $? -ne 0 ]; then
    printf 'Cannot measure campaign size: %s\n' "$path" >&2
    return 1
  fi
  REMOVABLE_ID="$id"
  REMOVABLE_PATH="$path"
  REMOVABLE_WORKTREES=("${children[@]}")
  return 0
}

wlv_assert_real_ancestors "$tempRoot" || exit 1

if [ "$ACTION" = 'New' ]; then
  path=''
  if [ "$ID" = '054' ]; then
    printf 'Campaign 054 is reserved for the preserved archive.\n' >&2
    exit 1
  fi
  path=$(wlv_assert_campaign_path "$tempRoot/$ID") || exit 1
  if [ -e "$path" ]; then
    printf 'Campaign already exists: %s\n' "$path" >&2
    exit 1
  fi
  if ! mkdir -p "$path"; then
    printf 'Cannot create campaign directory: %s\n' "$path" >&2
    exit 1
  fi
  for child in worktrees scratch logs results; do
    if ! mkdir "$path/$child"; then
      printf 'Cannot create campaign subdirectory: %s\n' "$path/$child" >&2
      exit 1
    fi
  done
  commit=$(git -C "$repo" rev-parse HEAD)
  if [ $? -ne 0 ]; then
    printf 'Cannot record repository commit.\n' >&2
    exit 1
  fi
  created_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  wlv_write_campaign "$path" "$ID" "$PURPOSE" "$commit" 'active' "$PRESERVE" "$created_at" '' || exit 1
  printf 'id=%s\n' "$ID"
  printf 'root=%s\n' "$path"
  printf 'temporary_directory=%s\n' "$path/scratch"
  exit 0
fi

if [ "$ACTION" = 'Complete' ] || [ "$ACTION" = 'Fail' ]; then
  path=''
  path=$(wlv_assert_campaign_path "$tempRoot/$ID") || exit 1
  record=$(wlv_read_campaign "$path") || exit 1
  id=$(wlv_field "$record" id)
  purpose=$(wlv_field "$record" purpose)
  commit=$(wlv_field "$record" commit)
  created_at=$(wlv_field "$record" created_at_utc)
  old_preserve=$(wlv_field "$record" preserve)
  status=$(wlv_field "$record" status)
  if [ "$id" = '054' ] || [ "$status" = 'archived' ]; then
    printf 'Archived campaigns cannot be changed.\n' >&2
    exit 1
  fi
  if [ "$ACTION" = 'Complete' ]; then
    status='completed'
  else
    status='failed'
  fi
  if [ "$PRESERVE" = true ] || [ "$old_preserve" = 'true' ]; then
    preserve='true'
  else
    preserve='false'
  fi
  closed_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  wlv_write_campaign "$path" "$id" "$purpose" "$commit" "$status" "$preserve" "$created_at" "$closed_at" || exit 1
  printf 'schema=wlv-campaign/1\n'
  printf 'id=%s\n' "$id"
  printf 'purpose=%s\n' "$purpose"
  printf 'commit=%s\n' "$commit"
  printf 'status=%s\n' "$status"
  printf 'preserve=%s\n' "$preserve"
  printf 'created_at_utc=%s\n' "$created_at"
  printf 'closed_at_utc=%s\n' "$closed_at"
  exit 0
fi

paths=()
if [ -n "$ID" ]; then
  listed=$(wlv_assert_campaign_path "$tempRoot/$ID") || exit 1
  paths+=("$listed")
elif [ -d "$tempRoot" ]; then
  listing=$(find "$tempRoot" -mindepth 1 -maxdepth 1 \
    \( -type d -o \( -type l -a -xtype d \) \) -print 2>/dev/null | sort)
  if [ $? -ne 0 ]; then
    printf 'Cannot list campaigns in temp directory.\n' >&2
    exit 1
  fi
  while IFS= read -r listed; do
    [ -n "$listed" ] || continue
    paths+=("$listed")
  done <<<"$listing"
fi

if [ "$ACTION" = 'Status' ]; then
  for path in "${paths[@]}"; do
    record=$(wlv_read_campaign "$path") || exit 1
    printf 'id=%s\n' "$(wlv_field "$record" id)"
    printf 'status=%s\n' "$(wlv_field "$record" status)"
    printf 'preserve=%s\n' "$(wlv_field "$record" preserve)"
    printf 'path=%s\n' "$path"
  done
  exit 0
fi

WLV_WORKTREES=$(wlv_get_worktrees) || exit 1

plan_paths=()
plan_ids=()
plan_bytes=()
plan_worktrees=()
for path in "${paths[@]}"; do
  record=$(wlv_read_campaign "$path") || exit 1
  id=$(wlv_field "$record" id)
  preserve=$(wlv_field "$record" preserve)
  status=$(wlv_field "$record" status)
  if [ "$id" = '054' ] || [ "$preserve" = 'true' ] || [ "$status" = 'archived' ]; then
    if [ -n "$ID" ]; then
      printf 'Campaign is preserved: %s\n' "$path" >&2
      exit 1
    fi
    continue
  fi
  if [ "$status" = 'active' ]; then
    if [ -n "$ID" ]; then
      printf 'Campaign is active: %s\n' "$path" >&2
      exit 1
    fi
    continue
  fi
  wlv_assert_removable_campaign "$path" || exit 1
  plan_paths+=("$REMOVABLE_PATH")
  plan_ids+=("$REMOVABLE_ID")
  plan_bytes+=("$REMOVABLE_BYTES")
  if [ "${#REMOVABLE_WORKTREES[@]}" -gt 0 ]; then
    plan_worktrees+=("$(printf '%s\n' "${REMOVABLE_WORKTREES[@]}")")
  else
    plan_worktrees+=('')
  fi
done

# Resolve every target and perform every preflight before the first deletion.
for index in "${!plan_paths[@]}"; do
  gib=$(awk -v bytes="${plan_bytes[$index]}" 'BEGIN { printf "%.3f", bytes / 1073741824 }')
  printf 'id=%s\n' "${plan_ids[$index]}"
  printf 'path=%s\n' "${plan_paths[$index]}"
  printf 'gib=%s\n' "$gib"
  printf 'apply=%s\n' "$APPLY"
done

if [ "$APPLY" != true ]; then
  exit 0
fi

for index in "${!plan_paths[@]}"; do
  path="${plan_paths[$index]}"
  WLV_WORKTREES=$(wlv_get_worktrees) || exit 1
  wlv_assert_removable_campaign "$path" || exit 1
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    # --force permits generated, ignored data; visible code changes were refused.
    if ! git -c core.longpaths=true -C "$repo" worktree remove --force "$wt"; then
      printf 'Git worktree removal failed: %s\n' "$wt" >&2
      exit 1
    fi
  done <<<"${plan_worktrees[$index]}"
  wlv_assert_campaign_path "$path" >/dev/null || exit 1
  if [ -e "$path" ]; then
    if ! rm -rf "$path"; then
      printf 'Campaign removal failed: %s\n' "$path" >&2
      exit 1
    fi
  fi
  if [ -e "$path" ]; then
    printf 'Campaign removal was incomplete: %s\n' "$path" >&2
    exit 1
  fi
done

#!/usr/bin/env bash
# Linux/bash counterpart of tests/manual/test-campaign-storage.ps1; keep both
# in sync. Creates a throwaway campaign under temp/ and verifies the cleanup
# boundaries: protected campaigns, path traversal, output containment, dry
# runs, dirty worktrees and removal scope.

set -o pipefail
LC_ALL=C
export LC_ALL

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P) || exit 1
manager="$repo/scripts/manage-campaigns.sh"
# shellcheck source=../../scripts/campaign-paths.sh
. "$repo/scripts/campaign-paths.sh"

command -v python3 >/dev/null 2>&1 || {
  printf 'Python 3 is required for the storage selftest.\n' >&2
  exit 1
}

uuid=$(python3 -c 'import uuid; print(uuid.uuid4().hex)') || exit 1
id="storage-selftest-$uuid"
root=''
worktree=''

on_exit() {
  local status=$?
  if [ -n "$root" ] && [ -e "$root" ]; then
    printf 'Selftest fixture retained for inspection: %s\n' "$root" >&2
  fi
  exit "$status"
}
trap on_exit EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

campaign=$(bash "$manager" -Action New -Id "$id" -Purpose 'Campaign cleanup boundary selftest') ||
  fail 'Cannot create the selftest campaign'
root=$(printf '%s\n' "$campaign" | sed -n 's/^root=//p')
[ -n "$root" ] || fail 'Campaign creation output is missing the root path.'
worktree="$root/worktrees/fixture"
outside="$repo/README.md"
outside_hash=$(sha256sum -- "$outside" | awk '{print $1}')

checks=()
expect_rejection() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "Expected rejection: $name"
  fi
  checks+=("$name")
}

# Active campaigns cannot be erased.
expect_rejection 'active campaign protected' bash "$manager" -Action Clean -Id "$id" -Apply
# The preserved 054 archive is always protected.
expect_rejection '054 protected' bash "$manager" -Action Clean -Id 054 -Apply
# Path traversal in ids is rejected at parameter validation.
expect_rejection 'traversal protected' bash "$manager" -Action New -Id '../escape'
# Outputs outside temp/<id>/ are rejected.
expect_rejection 'external output rejected' assert_wlv_campaign_output_path "$repo/run_logs/forbidden.json"
expect_rejection 'archive write rejected' assert_wlv_campaign_output_path "$repo/temp/054/new.json"
allowed=$(assert_wlv_campaign_output_path "$root/logs/allowed.json") ||
  fail 'Expected acceptance: active output accepted'
[ "$allowed" = "$root/logs/allowed.json" ] ||
  fail 'Resolved output path does not match the requested path.'
checks+=('active output accepted')

sentinel="$root/results/sentinel.txt"
printf 'preserve until apply' >"$sentinel" || fail 'Cannot write the sentinel result.'
bash "$manager" -Action Complete -Id "$id" >/dev/null ||
  fail 'Cannot complete the selftest campaign'
# Closed campaigns no longer accept outputs.
expect_rejection 'closed output rejected' assert_wlv_campaign_output_path "$root/logs/forbidden.json"
# Dry runs only list plans and keep every file in place.
bash "$manager" -Action Clean -Id "$id" >/dev/null ||
  fail 'Dry run refused a completed campaign'
[ -f "$sentinel" ] || fail 'Dry run deleted a result'
checks+=('dry run preserved files')

# Native Git worktree with ignored results is removed only after dirty code is
# resolved.
if ! git -c core.longpaths=true -C "$repo" worktree add --detach "$worktree" HEAD >/dev/null 2>&1; then
  fail 'Cannot create fixture worktree'
fi
readme="$worktree/README.md"
backup="$root/scratch/readme.orig"
cp -- "$readme" "$backup" || fail 'Cannot back up the worktree README.'
printf '\nselftest change\n' >>"$readme"
expect_rejection 'dirty worktree protected' bash "$manager" -Action Clean -Id "$id" -Apply
cp -- "$backup" "$readme" || fail 'Cannot restore the worktree README.'
mkdir -p "$worktree/results" || fail 'Cannot create the worktree results directory.'
printf 'ignored result' >"$worktree/results/generated.txt"
bash "$manager" -Action Clean -Id "$id" -Apply >/dev/null ||
  fail 'Clean -Apply refused a closed campaign with a clean worktree'
[ ! -e "$root" ] || fail 'Closed campaign was not removed'
[ "$(sha256sum -- "$outside" | awk '{print $1}')" = "$outside_hash" ] ||
  fail 'Outside file was altered'
checks+=('clean worktree and ignored results removed')
checks+=('outside source file preserved')

printf 'passed=true\n'
printf 'count=%s\n' "${#checks[@]}"
for check in "${checks[@]}"; do
  printf 'check=%s\n' "$check"
done

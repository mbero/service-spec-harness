#!/usr/bin/env bash
# Every gate, in the order a failure is cheapest to read.
#
# NOT `set -e`: each stage must run even after an earlier one fails, so one run
# shows the whole picture rather than the first thing that broke.
#
# Usage: [SPEC_ROOT=...] [TARGET=...] all.sh
set -uo pipefail
CHECK_NAME="all"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC_ROOT="${SPEC_ROOT:-$HARNESS_ROOT}"
TARGET="${TARGET:-}"

FAILED=""
COUNT=0
stage() {
  local name="$1"; shift
  printf '\n=== %s ===\n' "$name"
  if "$@"; then return 0; fi
  FAILED="$FAILED $name"
  COUNT=$((COUNT + 1))
  return 1
}

stage harness           "$HERE/harness.sh" "$SPEC_ROOT"
stage spec-completeness "$HERE/spec-completeness.sh" "$SPEC_ROOT"
stage oracle-integrity  "$HERE/oracle-integrity.sh" "$SPEC_ROOT"
stage secrets           "$HERE/secrets.sh" $TARGET

# The code checks need a target that exists. Before the first implementation
# step there is none, and that is not a failure — it is reported and skipped.
if [[ -n "$TARGET" && -d "$TARGET" ]] || "$HERE/../bin/py" -c "import sys" >/dev/null 2>&1 \
   && TARGET_RESOLVED="$(resolve_target "$TARGET" 2>/dev/null)"; then
  stage architecture    "$HERE/architecture.sh" "$TARGET_RESOLVED"
  stage forbidden-tech  "$HERE/forbidden-tech.sh" "$TARGET_RESOLVED"
else
  printf '\n=== architecture / forbidden-tech ===\n'
  note "skipped: no target repository yet (service.yaml repositories.target.path)"
fi

printf '\n'
if (( COUNT > 0 )); then
  printf '%sFAILED%s    [all] %d stage(s):%s\n' "$_c_red" "$_c_off" "$COUNT" "$FAILED" >&2
  exit 1
fi
printf '%sPASSED%s    [all] every stage green\n' "$_c_green" "$_c_off"
exit 0

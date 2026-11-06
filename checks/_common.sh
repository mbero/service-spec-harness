#!/usr/bin/env bash
# Shared helpers for the harness checks.
# Sourced, never executed directly.

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_ROOT

# Python always goes through bin/py: uv in the locked environment when uv is
# installed, python3 otherwise. Never call python3 directly.
PY="$HARNESS_ROOT/bin/py"
have_python() { "$PY" -c "import yaml" >/dev/null 2>&1; }

# The manifest and the architecture contract. Overridable so that the selftest
# and the worked example can run the real checks against their own copies
# instead of a near-duplicate written for testing.
MANIFEST="${MANIFEST_FILE:-$HARNESS_ROOT/service.yaml}"
ARCH="${ARCH_FILE:-$HARNESS_ROOT/architecture.yaml}"
export MANIFEST ARCH

VIOLATIONS=0
CHECK_NAME="${CHECK_NAME:-check}"

# Phase gate. tier S and M only ever have `main`; tier L overrides it.
PHASE="${PHASE:-main}"
export PHASE

_c_red=''; _c_green=''; _c_yellow=''; _c_off=''
if [[ -t 1 ]]; then
  _c_red=$'\033[31m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'; _c_off=$'\033[0m'
fi

violation() {
  VIOLATIONS=$((VIOLATIONS + 1))
  printf '%sVIOLATION%s [%s] %s\n' "$_c_red" "$_c_off" "$CHECK_NAME" "$*" >&2
}

note() { printf '%sNOTE%s      [%s] %s\n' "$_c_yellow" "$_c_off" "$CHECK_NAME" "$*"; }
ok()   { printf '%sOK%s        [%s] %s\n' "$_c_green" "$_c_off" "$CHECK_NAME" "$*"; }

# The specification root: the directory holding specification/, acceptance/ and
# gaps/. Defaults to the harness itself; an example or a copy under test passes
# its own path. This is what lets checks/selftest.sh run the real checks against
# a deliberately broken copy.
resolve_spec_root() {
  local s="${1:-$HARNESS_ROOT}"
  if [[ ! -d "$s/specification" ]]; then
    printf 'ERROR [%s] no specification/ under %s\n' "$CHECK_NAME" "$s" >&2
    exit 2
  fi
  ( cd "$s" && pwd )
}

# repositories.target.path from service.yaml, read with a real YAML parser
# rather than awk: the manifest is nested and hand-indented, and a parser that
# "mostly works" on it fails silently in exactly the cases that matter.
target_from_manifest() {
  "$PY" - "$MANIFEST" <<'PY' 2>/dev/null
import sys, os, yaml
try:
    m = yaml.safe_load(open(sys.argv[1]))
    p = (m.get("repositories") or {}).get("target", {}).get("path")
    if p and not os.path.isabs(p):
        # Relative to the manifest, never to the caller's cwd: a check must
        # resolve the same target wherever it is invoked from.
        p = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), p))
    print(p if p else "")
except Exception:
    print("")
PY
}

# $1 overrides the manifest. Exits 2 if the path does not exist or is still a
# <<REQUIRED>> marker.
resolve_target() {
  local t="${1:-}"
  [[ -n "$t" ]] || t="$(target_from_manifest)"
  if [[ -z "$t" || "$t" == *"<<REQUIRED"* ]]; then
    printf 'ERROR [%s] repositories.target.path is not set in service.yaml\n' "$CHECK_NAME" >&2
    exit 2
  fi
  if [[ ! -d "$t" ]]; then
    printf 'ERROR [%s] target repository does not exist: %s\n' "$CHECK_NAME" "$t" >&2
    exit 2
  fi
  printf '%s' "$t"
}

# Directories that are never source. `scan_files` prunes them via find; a check
# reaching for `grep -r` instead must pass "${GREP_PRUNE[@]}", or it scans build
# output and reports stale findings long after the source was fixed.
GREP_PRUNE=(--exclude-dir=target --exclude-dir=.git --exclude-dir=.idea --exclude-dir=build)

scan_files() {
  local root="$1"; shift
  find "$root" \
    -path '*/target/*' -prune -o \
    -path '*/.git/*'   -prune -o \
    -path '*/.idea/*'  -prune -o \
    -path '*/build/*'  -prune -o \
    -type f "$@" -print 2>/dev/null
}

# Reads VIOLATION|... and NOTE|... lines emitted by an embedded Python block and
# turns them into this script's counters. Keeps the parsing in one place.
consume_findings() {
  local line
  while IFS= read -r line; do
    case "$line" in
      VIOLATION\|*) violation "${line#VIOLATION|}" ;;
      NOTE\|*)      note      "${line#NOTE|}" ;;
      OK\|*)        ok        "${line#OK|}" ;;
      '')           ;;
      *)            printf '%s\n' "$line" ;;
    esac
  done
}

finish() {
  if (( VIOLATIONS > 0 )); then
    printf '\n%sFAILED%s    [%s] %d violation(s)\n' "$_c_red" "$_c_off" "$CHECK_NAME" "$VIOLATIONS" >&2
    exit 1
  fi
  printf '\n%sPASSED%s    [%s]\n' "$_c_green" "$_c_off" "$CHECK_NAME"
  exit 0
}

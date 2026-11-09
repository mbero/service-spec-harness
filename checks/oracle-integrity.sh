#!/usr/bin/env bash
# The oracle is what it was when a person approved it — or this fails.
#
# ---------------------------------------------------------------------------
# Why this exists
# ---------------------------------------------------------------------------
#
# `.claude/settings.json` `permissions.deny` restricts the `Write` and `Edit`
# tools. It does not restrict `Bash`, and every implementing agent has `Bash`.
# One redirection reaches `acceptance/`, and the path rule never sees it.
#
# So the guarantee cannot live in a path rule. It lives here instead: one
# SHA-256 per file under `acceptance/`, recorded when a person approved the
# cases. The hash does not care which tool wrote the bytes. `Write`, `Edit`,
# `Bash`, a text editor and a stray `sed -i` are all the same to it.
#
# This check does not PREVENT a write. It makes an unapproved one impossible
# to ship, which is the property the harness actually needs.
#
# ---------------------------------------------------------------------------
# The re-seal question
# ---------------------------------------------------------------------------
#
# An agent with `Bash` can also run `--seal` and re-record its own tampering.
# What stops that is not this script: the manifest is committed, so a re-seal
# appears as a changed `state/oracle-manifest.sha256` in the diff you read
# before committing — and no agent commits (`prompts/system.md` §3).
#
# If you ever find a manifest change in a diff you did not seal yourself, the
# step that produced it is void. Say so out loud rather than re-sealing again.
#
# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
#
#   oracle-integrity.sh [SPEC_ROOT]          verify. The gate.
#   oracle-integrity.sh --seal [SPEC_ROOT]   record the current state.
#
# Seal AFTER a person approved the cases, never before, and never to make a red
# run green. SPEC_ROOT defaults to the harness root; the selftest passes its
# own temporary copy.
set -euo pipefail
CHECK_NAME="oracle-integrity"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MANIFEST_NAME="state/oracle-manifest.sha256"

SEAL=0
if [[ "${1:-}" == "--seal" ]]; then SEAL=1; shift; fi

SPEC="$(resolve_spec_root "${1:-$HARNESS_ROOT}")"
ORACLE="$SPEC/acceptance"
MANIFEST="$SPEC/$MANIFEST_NAME"

# macOS ships shasum, most Linux images ship sha256sum. Either is fine; a
# missing one is not, because then this check would silently pass on nothing.
if command -v shasum >/dev/null 2>&1; then
  _hash() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  _hash() { sha256sum "$1" | awk '{print $1}'; }
else
  printf 'ERROR [%s] neither shasum nor sha256sum is available\n' "$CHECK_NAME" >&2
  exit 2
fi

# Every file under acceptance/, relative to SPEC, sorted. .DS_Store is noise
# macOS creates by opening a folder in Finder; it is not part of the oracle.
# `|| true` on every find: with `pipefail`, a find over a directory that does
# not exist yet kills the whole script before it reports anything. A missing
# acceptance/cases is the normal state of a fresh instantiation, not an error.
list_files() {
  { find "$ORACLE" -type f ! -name '.DS_Store' 2>/dev/null || true; } \
    | sed "s|^$SPEC/||" | LC_ALL=C sort
}

count_cases() {
  { find "$ORACLE/cases" -type f -name '*.yaml' 2>/dev/null || true; } | wc -l | tr -d ' '
}

# --- seal -------------------------------------------------------------------

if (( SEAL )); then
  [[ -d "$ORACLE" ]] || { printf 'ERROR [%s] no acceptance/ under %s\n' "$CHECK_NAME" "$SPEC" >&2; exit 2; }
  mkdir -p "$(dirname "$MANIFEST")"
  {
    printf '# Oracle manifest — one SHA-256 per file under acceptance/.\n'
    printf '# Written by checks/oracle-integrity.sh --seal. Commit it.\n'
    printf '# Re-seal only after a person approved what changed.\n'
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      printf '%s  %s\n' "$(_hash "$SPEC/$rel")" "$rel"
    done < <(list_files)
  } > "$MANIFEST"
  n="$(grep -vc '^#' "$MANIFEST" || true)"
  ok "sealed $n file(s) into $MANIFEST_NAME"
  note "commit the manifest. An unseal you did not make is a void step."
  exit 0
fi

# --- verify -----------------------------------------------------------------

note "oracle: ${ORACLE#"$SPEC"/} under $SPEC"

if [[ ! -d "$ORACLE" ]]; then
  violation "no acceptance/ directory — there is no oracle to protect"
  finish
fi

CASES="$(count_cases)"

if [[ ! -f "$MANIFEST" ]]; then
  if (( CASES == 0 )); then
    # A fresh instantiation before /spec-elicit. Nothing is approved yet, so
    # there is nothing to seal and nothing to compare.
    ok "no cases yet and no manifest — nothing to protect"
    finish
  fi
  violation "$CASES acceptance case(s) exist but $MANIFEST_NAME does not — \
run checks/oracle-integrity.sh --seal after a person approves them"
  finish
fi

# Compare by path first, then by hash. The manifest line is
# `<64 hex><two spaces><path>`, so both halves split on that separator without
# a parser — and a path containing a space still works, which matters because
# real note trees have them.
EXPECTED="$(mktemp)"; ACTUAL="$(mktemp)"
trap 'rm -f "$EXPECTED" "$ACTUAL"' EXIT

grep -v '^#' "$MANIFEST" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$EXPECTED" || true

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  printf '%s  %s\n' "$(_hash "$SPEC/$rel")" "$rel"
done < <(list_files) | LC_ALL=C sort > "$ACTUAL"

paths_of() { sed 's/^[0-9a-f]\{64\}  //' "$1" | LC_ALL=C sort; }

# The hash recorded for one path, or empty. Reads the file rather than greps
# it: a path is untrusted text and a regex over it is a bug waiting to happen.
hash_for() {
  local line
  while IFS= read -r line; do
    [[ "${line#*  }" == "$2" ]] || continue
    printf '%s' "${line%%  *}"
    return 0
  done < "$1"
  return 0
}

while IFS= read -r rel; do
  [[ -n "$rel" ]] && violation "removed from the oracle since it was sealed: $rel"
done < <(comm -23 <(paths_of "$EXPECTED") <(paths_of "$ACTUAL"))

while IFS= read -r rel; do
  [[ -n "$rel" ]] && violation "added to the oracle since it was sealed: $rel"
done < <(comm -13 <(paths_of "$EXPECTED") <(paths_of "$ACTUAL"))

# Same path, different content. This is the case the whole script exists for.
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  want="$(hash_for "$EXPECTED" "$rel")"
  have="$(hash_for "$ACTUAL" "$rel")"
  if [[ -n "$want" && -n "$have" && "$want" != "$have" ]]; then
    violation "the oracle changed after it was sealed: $rel"
  fi
done < <(comm -12 <(paths_of "$EXPECTED") <(paths_of "$ACTUAL"))

SEALED_COUNT="$(grep -vc '^#' "$MANIFEST" || true)"
(( VIOLATIONS == 0 )) && ok "$SEALED_COUNT oracle file(s) match the seal"
finish

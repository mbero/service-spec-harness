#!/usr/bin/env bash
# Fails if a credential appears anywhere in the target or in this harness.
#
# Scope note: this is a tripwire, not a scanner. It catches the four shapes that
# actually reach these repositories — a token pasted into a test constant, a
# password in application.yml, a bearer value in a fixture, a key in a report.
# It is not a replacement for a real secret scanner in CI.
#
# Usage: secrets.sh [TARGET_PATH]
set -euo pipefail
CHECK_NAME="secrets"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# `resolve_target` exits 2 when no target is configured yet. Inside a command
# substitution that exit status propagates to the assignment, and `set -e` then
# kills this script before it scans anything — which is wrong: the harness
# itself is always worth scanning, target or no target. An `if` makes the
# failure recoverable.
TARGET=""
if _t="$(resolve_target "${1:-}" 2>/dev/null)"; then
  TARGET="$_t"
fi
ROOTS=("$HARNESS_ROOT")
[[ -n "$TARGET" && -d "$TARGET" ]] && ROOTS+=("$TARGET")
note "scanning: ${ROOTS[*]}"

# A JWT-shaped literal, a bearer value that is not a placeholder, and the usual
# assignment forms. {{token}} and ${ENV_VAR} are the sanctioned placeholders.
scan() {
  local label="$1" pattern="$2"; shift 2
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    case "$hit" in
      *'{{token}}'*|*'${'*|*'<<REQUIRED'*) continue ;;
    esac
    violation "$label: $hit"
  done < <(grep -rnE "$pattern" "${GREP_PRUNE[@]}" \
             --include='*.java' --include='*.kt' --include='*.groovy' \
             --include='*.yaml' --include='*.yml' --include='*.json' \
             --include='*.properties' --include='*.md' \
             "${ROOTS[@]}" 2>/dev/null | sed "s|$HARNESS_ROOT/||" || true)
}

scan "JWT literal"      'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'
scan "bearer literal"   '[Bb]earer[[:space:]]+[A-Za-z0-9._-]{16,}'
scan "assigned secret"  '(password|passwd|secret|apikey|api_key|client_secret|private_key)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_.-]{8,}'

(( VIOLATIONS == 0 )) && ok "no credential-shaped literal in the harness or the target"
finish

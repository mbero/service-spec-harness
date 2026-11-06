#!/usr/bin/env bash
# Fails if the target uses anything service.yaml `constraints.forbidden` bans.
#
# One generic check instead of one script per banned technology. Banning a
# library is a one-line edit to the manifest, which means it actually happens.
#
# Usage: [MANIFEST_FILE=...] forbidden-tech.sh [TARGET_PATH]
set -euo pipefail
CHECK_NAME="forbidden-tech"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

TARGET="$(resolve_target "${1:-}")"
note "target: $TARGET"

if ! have_python; then
  violation "Python with PyYAML is required (bin/py)"
  finish
fi

# The manifest is read once and emitted as TSV, so the grep loop stays in bash
# where the file globbing belongs.
RULES="$("$PY" - "$MANIFEST" <<'PY'
import sys, yaml
m = yaml.safe_load(open(sys.argv[1])) or {}
for e in ((m.get("constraints") or {}).get("forbidden") or []):
    pat = e.get("pattern", "")
    files = e.get("files") or ["*"]
    reason = e.get("reason", "")
    if pat:
        print("\t".join([pat, ",".join(files), reason]))
PY
)"

if [[ -z "$RULES" ]]; then
  violation "constraints.forbidden is empty — this check would pass on anything"
  finish
fi

RULE_COUNT=0
while IFS=$'\t' read -r PATTERN FILES REASON; do
  [[ -n "$PATTERN" ]] || continue
  RULE_COUNT=$((RULE_COUNT + 1))
  INCLUDES=()
  IFS=',' read -r -a GLOBS <<< "$FILES"
  for g in "${GLOBS[@]}"; do INCLUDES+=("--include=$g"); done
  while IFS= read -r hit; do
    [[ -n "$hit" ]] && violation "${hit} — ${REASON}"
  done < <(grep -rnE "$PATTERN" "${GREP_PRUNE[@]}" "${INCLUDES[@]}" "$TARGET" 2>/dev/null \
             | sed "s|^$TARGET/||" || true)
done <<< "$RULES"

note "$RULE_COUNT forbidden-technology rule(s) applied"
(( VIOLATIONS == 0 )) && ok "no forbidden technology in the target"
finish

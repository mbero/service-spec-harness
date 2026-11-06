#!/usr/bin/env bash
# The harness checks itself.
#
# Every artefact in this repository is half of a pair: decisions.md and
# decisions.yaml, service.yaml and the checks that read it, acceptance/ and the
# deny rule that protects it. Pairs drift. This script is the only thing that
# notices.
#
# Usage: harness.sh [ROOT]   ROOT defaults to the harness root; the selftest
#                            passes a deliberately broken copy.
set -euo pipefail
CHECK_NAME="harness"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

HROOT="${1:-$HARNESS_ROOT}"
HROOT="$(cd "$HROOT" && pwd)"
note "root: $HROOT"

if ! have_python; then
  violation "Python with PyYAML is required (bin/py)"
  finish
fi

# --- 1. Unfilled markers ----------------------------------------------------
# The template ships <<REQUIRED: ...>> markers on purpose: a TODO comment rots
# silently, a marker is checked. The consequence is that the TEMPLATE itself
# never passes this check — only an instantiation does.
while IFS= read -r hit; do
  [[ -n "$hit" ]] && violation "unfilled marker: $hit"
done < <(grep -rn '<<REQUIRED' \
           "${GREP_PRUNE[@]}" --exclude-dir=examples --exclude-dir=docs \
           --include='service.yaml' --include='architecture.yaml' \
           --include='*.yaml' --include='*.md' \
           "$HROOT/service.yaml" "$HROOT/architecture.yaml" \
           "$HROOT/specification" "$HROOT/acceptance/cases" 2>/dev/null \
           | sed "s|^$HROOT/||" \
           | grep -v '^specification/README.md' \
           | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
# The last filter drops comment lines. A file is allowed to EXPLAIN the marker
# convention; it is not allowed to still carry an unfilled one.

# --- 2. decisions.md and decisions.yaml describe the same id set ------------
if [[ -f "$HROOT/decisions.md" && -f "$HROOT/decisions.yaml" ]]; then
  MD_IDS="$(grep -oE '^## PD-[0-9]{3}' "$HROOT/decisions.md" | grep -oE 'PD-[0-9]{3}' | sort -u || true)"
  YML_IDS="$("$PY" - "$HROOT/decisions.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for e in (d.get("decisions") or []):
    if isinstance(e, dict) and e.get("id"):
        print(str(e["id"]).strip())
PY
)"
  YML_IDS="$(printf '%s\n' "$YML_IDS" | sed '/^$/d' | sort -u)"
  if [[ "$MD_IDS" != "$YML_IDS" ]]; then
    violation "decisions.md and decisions.yaml disagree on the decision id set"
    note "only in decisions.md:   $(comm -23 <(printf '%s\n' "$MD_IDS") <(printf '%s\n' "$YML_IDS") | tr '\n' ' ')"
    note "only in decisions.yaml: $(comm -13 <(printf '%s\n' "$MD_IDS") <(printf '%s\n' "$YML_IDS") | tr '\n' ' ')"
  fi
else
  violation "decisions.md or decisions.yaml is missing"
fi

# --- 3. The deny rules that protect the oracle ------------------------------
SETTINGS="$HROOT/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  violation ".claude/settings.json is missing — nothing stops an agent writing to acceptance/"
else
  MISSING="$("$PY" - "$SETTINGS" <<'PY'
import sys, json
try:
    cfg = json.load(open(sys.argv[1]))
except Exception as exc:
    print(f"settings.json is not valid JSON: {exc}")
    raise SystemExit(0)
deny = (cfg.get("permissions") or {}).get("deny") or []
joined = " ".join(deny)
for tool in ("Write", "Edit"):
    if f"{tool}(./acceptance/" not in joined and f"{tool}(acceptance/" not in joined:
        print(f"permissions.deny has no {tool}(./acceptance/**) rule")
PY
)"
  while IFS= read -r line; do
    [[ -n "$line" ]] && violation "$line"
  done <<< "$MISSING"
fi

# --- 4. Manifest consistency ------------------------------------------------
MANIFEST_FINDINGS="$("$PY" - "$HROOT" <<'PY'
import sys, os, yaml
root = sys.argv[1]
out = []
mp = os.path.join(root, "service.yaml")
if not os.path.exists(mp):
    print("service.yaml is missing"); raise SystemExit(0)
try:
    m = yaml.safe_load(open(mp)) or {}
except Exception as exc:
    print(f"service.yaml is not valid YAML: {exc}"); raise SystemExit(0)

h = m.get("harness") or {}
mode, tier = h.get("mode"), h.get("tier")
if mode not in {"greenfield", "port", "rewrite"}:
    out.append(f"harness.mode '{mode}' is not greenfield, port or rewrite")
if tier not in {"S", "M", "L"}:
    out.append(f"harness.tier '{tier}' is not S, M or L")

ref = ((m.get("repositories") or {}).get("reference") or {})
ref_path = ref.get("path")
if mode == "greenfield" and ref_path:
    out.append("mode is greenfield but repositories.reference.path is set — "
               "a greenfield build has no oracle to point at, and half the "
               "checks would silently start comparing against it")
if mode in {"port", "rewrite"} and not ref_path:
    out.append(f"mode is {mode} but repositories.reference.path is empty — "
               f"the oracle is the whole point of that mode")
if ref_path and ref.get("read_only") is not True:
    out.append("repositories.reference.read_only is not true")

req = ((m.get("validation") or {}).get("required") or [])
if tier == "S" and "advisor_review" in req:
    out.append("tier S declares advisor_review — tier S has no advisor")
if tier in {"M", "L"} and "advisor_review" not in req:
    out.append(f"tier {tier} does not require advisor_review")
if "spec_completeness" not in req:
    out.append("validation.required omits spec_completeness — the one gate that "
               "distinguishes this harness from a prompt")
if "acceptance_cases" not in req:
    out.append("validation.required omits acceptance_cases")

for ph in (m.get("phases") or []):
    c = ph.get("contract")
    if c and not os.path.exists(os.path.join(root, c)):
        out.append(f"phase {ph.get('id')} names contract {c}, which does not exist")

if tier in {"S", "M"} and len(m.get("phases") or []) > 1:
    out.append(f"tier {tier} declares {len(m['phases'])} phases — only tier L is phased")

print("\n".join(out))
PY
)"
while IFS= read -r line; do
  [[ -n "$line" ]] && violation "$line"
done <<< "$MANIFEST_FINDINGS"

# --- 5. Every check is covered by the selftest ------------------------------
# "Never ship a check that cannot fail" is a rule, so it is checked.
SELFTEST="$HARNESS_ROOT/checks/selftest.sh"
if [[ ! -f "$SELFTEST" ]]; then
  violation "checks/selftest.sh is missing — no check in this repository has been observed failing"
else
  for f in "$HARNESS_ROOT"/checks/*.sh; do
    b="$(basename "$f")"
    case "$b" in _common.sh|all.sh|selftest.sh) continue ;; esac
    [[ -x "$f" ]] || violation "checks/$b is not executable"
    grep -q "$b" "$SELFTEST" || \
      violation "checks/$b is never exercised by checks/selftest.sh — it has not been observed failing"
  done
fi

(( VIOLATIONS == 0 )) && ok "harness artefacts agree with each other"
finish

#!/usr/bin/env bash
# The harness checks itself.
#
# Every artefact in this repository is half of a pair: service.yaml and the
# checks that read it, acceptance/ and the deny rule that protects it, a check
# script and the selftest case that proves it can fail. Pairs drift. This
# script is the only thing that notices.
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
           | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
# The last filter drops comment lines. A file is allowed to EXPLAIN the marker
# convention; it is not allowed to still carry an unfilled one.

# --- 2. The deny rules, and the one that must NOT be there ------------------
# A path deny restricts the `Write` and `Edit` tools and nothing else. `Bash`
# is not covered, and every implementing agent has `Bash`, so a deny on
# `acceptance/` never protected the oracle — it only blocked `spec-author`,
# the one agent that is supposed to write there. That agent then wrote its
# cases through shell heredocs, which is the worse outcome: the oracle still
# changed, and the only route to it was the one nobody could see.
#
# The oracle is protected by content now — `checks/oracle-integrity.sh`. This
# section checks two things: the fixture deny is still present, and the oracle
# deny has not come back.
SETTINGS="$HROOT/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  violation ".claude/settings.json is missing — nothing stops an agent writing to examples/"
else
  MISSING="$("$PY" - "$SETTINGS" "$HROOT" <<'PY'
import sys, json, os
try:
    cfg = json.load(open(sys.argv[1]))
except Exception as exc:
    print(f"settings.json is not valid JSON: {exc}")
    raise SystemExit(0)
deny = (cfg.get("permissions") or {}).get("deny") or []
joined = " ".join(deny)

# examples/ is the selftest fixture. Editing it to make checks/selftest.sh
# green removes the only proof the checks can fail at all. An instantiation
# ships no fixture, so the rule is required only where the directory is.
if os.path.isdir(os.path.join(sys.argv[2], "examples")):
    for tool in ("Write", "Edit"):
        if f"{tool}(./examples/" not in joined and f"{tool}(examples/" not in joined:
            print(f"permissions.deny has no {tool}(./examples/**) rule")

# A deny here is a regression, not a hardening. See the comment above.
for tool in ("Write", "Edit"):
    if f"{tool}(./acceptance/" in joined or f"{tool}(acceptance/" in joined:
        print(f"permissions.deny carries {tool}(./acceptance/**) — that rule blocks "
              f"spec-author, the only agent that must write the oracle, and stops no "
              f"Bash write at all. checks/oracle-integrity.sh protects it instead")
PY
)"
  while IFS= read -r line; do
    [[ -n "$line" ]] && violation "$line"
  done <<< "$MISSING"
fi

# --- 3. Manifest consistency ------------------------------------------------
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

# The architecture contract declares its own pattern, and the declaration has
# to agree with the rules underneath it. Nothing is required here when the
# field is absent: the field was added after the worked example was frozen, and
# the TEMPLATE carries it as an unfilled marker, so section 1 above is what
# makes an instantiation answer. This section checks the answer.
PATTERNS = {"hexagonal", "layered", "modular-monolith"}
ap = os.path.join(root, "architecture.yaml")
if os.path.exists(ap):
    try:
        a = yaml.safe_load(open(ap)) or {}
    except Exception as exc:
        a = {}
        out.append(f"architecture.yaml is not valid YAML: {exc}")
    pat = (a.get("pattern") or {})
    name = pat.get("name")
    if name:
        if name not in PATTERNS:
            out.append(f"architecture.yaml pattern.name '{name}' is none of "
                       f"{', '.join(sorted(PATTERNS))} — an agent cannot follow "
                       f"a pattern the contract does not define")
        if not str(pat.get("evidence") or "").strip():
            out.append("architecture.yaml declares pattern.name but no "
                       "pattern.evidence — the pattern governs every step, so "
                       "who chose it and when is part of the contract")
        if name == "hexagonal":
            # The claim is checkable, and this is the whole of it: hexagonal
            # means the domain owns the interfaces. A contract that says
            # hexagonal with no ports has renamed layered.
            layers = ((a.get("package-layout") or {}).get("layers") or {})
            pkgs = [p for layer in layers.values()
                    for p in ((layer or {}).get("packages") or [])]
            missing = [p for p in ("domain.port.in", "domain.port.out")
                       if p not in pkgs]
            if missing:
                out.append(f"architecture.yaml declares pattern hexagonal but "
                           f"package-layout names no {' and no '.join(missing)} "
                           f"— without the ports the domain cannot own its own "
                           f"interfaces, which is the only thing the word means")
            rules = a.get("import-rules") or []
            guards_domain = any(
                "/domain/" in str(r.get("in_package") or "")
                and any("adapter" in str(f.get("pattern") or "")
                        for f in (r.get("forbidden_imports") or []))
                for r in rules)
            if not guards_domain:
                out.append("architecture.yaml declares pattern hexagonal but no "
                           "import rule stops a domain type importing an "
                           "adapter — the pattern is then a comment")

print("\n".join(out))
PY
)"
while IFS= read -r line; do
  [[ -n "$line" ]] && violation "$line"
done <<< "$MANIFEST_FINDINGS"

# --- 4. Every agent names a model -------------------------------------------
# An agent with no `model:` inherits the session model. That means the step
# that writes the most code and the adversarial gate that doubts it run on the
# same model, and the bill looks the same whichever one you were paying for.
# Which model fits which role is a decision; an undeclared model is a default
# pretending to be one.
AGENTS_DIR="$HROOT/.claude/agents"
if [[ -d "$AGENTS_DIR" ]]; then
  for agent_file in "$AGENTS_DIR"/*.md; do
    [[ -e "$agent_file" ]] || continue
    grep -qE '^model:' "$agent_file" || \
      violation ".claude/agents/$(basename "$agent_file") names no model — it inherits the session model silently"
  done
fi

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

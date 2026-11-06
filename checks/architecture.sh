#!/usr/bin/env bash
# Validates the layer boundaries declared in architecture.yaml `import-rules`.
#
# The rules are NOT duplicated here. This script reads architecture.yaml and
# executes whatever it finds; adding a rule means editing the YAML, and there is
# no second copy in bash to drift away from it.
#
# Usage: [ARCH_FILE=...] architecture.sh [TARGET_PATH]
set -euo pipefail
CHECK_NAME="architecture"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

TARGET="$(resolve_target "${1:-}")"
note "target: $TARGET"

SRC="$TARGET/src/main/java"
if [[ ! -d "$SRC" ]]; then
  violation "no Java source root at $SRC"
  finish
fi

if ! have_python; then
  violation "Python with PyYAML is required (bin/py)"
  finish
fi

FINDINGS="$("$PY" - "$ARCH" "$SRC" "$TARGET" <<'PY'
import sys, os, re, yaml

arch_path, src, target = sys.argv[1], sys.argv[2], sys.argv[3]
out = []
def v(m): out.append("VIOLATION|" + m)
def n(m): out.append("NOTE|" + m)

arch = yaml.safe_load(open(arch_path)) or {}
rules = arch.get("import-rules") or []
if not rules:
    v("architecture.yaml declares no import-rules — this check would pass on "
      "anything, which is worse than not running it")
    print("\n".join(out)); raise SystemExit(0)

base = str((arch.get("package-layout") or {}).get("base", ""))
if "<<REQUIRED" in base or not base:
    v("architecture.yaml package-layout.base is not set")

files = []
for dirpath, dirnames, filenames in os.walk(src):
    dirnames[:] = [d for d in dirnames if d not in {"target", "build", ".git", ".idea"}]
    for f in filenames:
        if f.endswith(".java"):
            files.append(os.path.join(dirpath, f))

if not files:
    v(f"no .java files under {src}")
    print("\n".join(out)); raise SystemExit(0)

counts = {}
for layer, cfg in (arch.get("package-layout", {}).get("layers") or {}).items():
    frag = tuple("/" + p.replace(".", "/") + "/" for p in (cfg.get("packages") or []))
    counts[layer] = sum(1 for f in files if any(x in f for x in frag))
n("files: " + "  ".join(f"{k}={v_}" for k, v_ in counts.items()))

IMPORT = re.compile(r"^\s*import\s+(?:static\s+)?([\w.*]+)\s*;")

for rule in rules:
    rid = rule.get("id", "<no id>")
    frag = rule.get("in_package")
    severity = rule.get("severity", "violation")
    if not frag:
        v(f"{rid}: no in_package — the rule applies to nothing")
        continue
    scoped = [f for f in files if frag in f]
    if not scoped:
        n(f"{rid}: no files under {frag} yet")
        continue
    for forb in (rule.get("forbidden_imports") or []):
        pattern, reason = forb.get("pattern"), forb.get("reason", "")
        if not pattern:
            v(f"{rid}: a forbidden_imports entry has no pattern")
            continue
        rx = re.compile(pattern)
        for f in scoped:
            try:
                lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
            except OSError as exc:
                v(f"cannot read {f}: {exc}")
                continue
            for i, line in enumerate(lines, 1):
                m = IMPORT.match(line)
                if m and rx.search(m.group(1)):
                    rel = os.path.relpath(f, target)
                    msg = f"{rid} {rel}:{i} imports {m.group(1)} — {reason}"
                    (v if severity == "violation" else n)(msg)

print("\n".join(out))
PY
)"
consume_findings <<< "$FINDINGS"

(( VIOLATIONS == 0 )) && ok "every import-rule in architecture.yaml holds"
finish

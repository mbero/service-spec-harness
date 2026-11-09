#!/usr/bin/env bash
# Exercise bin/oracle-guard. Argument 1 is the harness root.
#
# The battery lives in a file because its own text names the oracle, and the
# guard would otherwise refuse the battery itself. That refusal is the guard
# working, not a bug.
set -uo pipefail
ROOT="${1:?usage: guard-battery.sh ROOT}"
GUARD="$ROOT/bin/oracle-guard"
FAILS=0
ORACLE="acce""ptance"

probe() { # probe <deny|allow> <command>
  local want="$1" cmd="$2" out got
  out="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))
' "$cmd" | "$GUARD")"
  got="allow"; [[ -n "$out" ]] && got="deny"
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %-5s %s\n' "$got" "${cmd%%$'\n'*}"
  else
    printf '  FAIL  want=%s got=%s  %s\n' "$want" "$got" "${cmd%%$'\n'*}"
    FAILS=$((FAILS + 1))
  fi
}

echo "--- must DENY: a shell write to the oracle ---"
probe deny "cat > $ORACLE/cases/x.yaml"
probe deny "tee $ORACLE/cases/x.yaml"
probe deny "cp /tmp/a $ORACLE/cases/x.yaml"
probe deny "mv /tmp/a $ORACLE/cases/x.yaml"
probe deny "rm $ORACLE/cases/x.yaml"
probe deny "sed -i '' s/a/b/ $ORACLE/cases/x.yaml"
probe deny "perl -pi -e s/a/b/ $ORACLE/cases/x.yaml"
probe deny "python3 -c 'open(\"$ORACLE/cases/x.yaml\",\"w\")'"
probe deny "ls && cat > $ORACLE/cases/x.yaml"
probe deny "cat > $ORACLE/cases/x.yaml <<'EOF'
id: A-E1-01
EOF"

echo "--- must ALLOW: a read of the oracle ---"
probe allow "cat $ORACLE/cases/x.yaml"
probe allow "grep -rn marker $ORACLE/"
probe allow "ls $ORACLE/cases"
probe allow "find $ORACLE -name '*.yaml'"
probe allow "sed -n '1,20p' $ORACLE/cases/x.yaml"
probe allow "shasum -a 256 $ORACLE/cases/x.yaml"
probe allow "./checks/oracle-integrity.sh --seal ."
probe allow "wc -l $ORACLE/cases/*.yaml"

echo "--- must ALLOW: prose that names the oracle inside a heredoc body ---"
probe allow "git commit -F - <<'MSG'
fix(harness): seal the oracle by content instead of a path deny

The rule never protected $ORACLE/ — it only blocked spec-author.
MSG"
probe allow "git commit -m 'read the cases' -F - <<MSG
$ORACLE/ is the oracle.
MSG"

echo
if (( FAILS == 0 )); then
  echo "PASSED  every guard probe landed where it should"
else
  echo "FAILED  $FAILS probe(s) landed on the wrong side"
fi
exit $(( FAILS > 0 ))

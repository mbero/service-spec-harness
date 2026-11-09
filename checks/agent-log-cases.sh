#!/usr/bin/env bash
# Exercise bin/agent-log attribution. Argument 1 is the harness root.
#
# The log answers one question — which agent did this — and it answered it
# wrongly for a while, because it attributed by transcript hash and every row
# of a real 259-row log carried the same hash. A fix nobody can see fail is
# worth as little as the bug was. So: feed synthetic hook payloads in, read the
# rendered timeline out, and assert the name on each line.
#
# AGENT_LOG points the script at a scratch file, so this never touches
# reports/agent-log.tsv.
set -uo pipefail
ROOT="${1:?usage: agent-log-cases.sh ROOT}"
LOGGER="$ROOT/bin/agent-log"
FAILS=0

WORK="$(mktemp -d "${TMPDIR:-/tmp}/agentlog.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export AGENT_LOG="$WORK/log.tsv"

# feed <hook_event_name> <tool_name> <json_tool_input>
feed() {
  python3 -c '
import json, sys
print(json.dumps({
    "hook_event_name": sys.argv[1],
    "tool_name": sys.argv[2],
    "tool_input": json.loads(sys.argv[3]),
    "transcript_path": "/same/path/for/everyone.jsonl",
}))' "$1" "$2" "$3" | "$LOGGER" hook
}

task_start() { feed PreToolUse  Task "{\"subagent_type\": \"$1\", \"description\": \"$1 work\"}"; }
task_end()   { feed PostToolUse Task "{\"subagent_type\": \"$1\", \"description\": \"$1 work\"}"; }
wrote()      { feed PostToolUse Write "{\"file_path\": \"$1\"}"; }
ran()        { feed PostToolUse Bash "{\"command\": \"$1\"}"; }
subagent_stop() { feed SubagentStop "" '{}'; }

# expect_actor <label> <path-or-command fragment> <agent name>
expect_actor() {
  local label="$1" needle="$2" want="$3" line got
  line="$("$LOGGER" show | grep -F -- "$needle" | head -1)"
  got="$(printf '%s' "$line" | awk '{print $2}')"
  if [[ "$got" == "$want" ]]; then
    printf '  ok    %-16s %s\n' "$want" "$label"
  else
    printf '  FAIL  want=%s got=%s  %s\n' "$want" "${got:-<no line>}" "$label"
    FAILS=$((FAILS + 1))
  fi
}

expect_show() { # expect_show <label> <needle>
  if "$LOGGER" show | grep -qF -- "$2"; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s — show never printed %s\n' "$1" "$2"
    FAILS=$((FAILS + 1))
  fi
}

expect_show_limited() { # expect_show_limited <label> <needle>
  if "$LOGGER" show -n 3 | grep -qF -- "$2"; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s — `show -n 3` never printed %s\n' "$1" "$2"
    FAILS=$((FAILS + 1))
  fi
}

refute_show() { # refute_show <label> <needle>
  if "$LOGGER" show | grep -qF -- "$2"; then
    printf '  FAIL  %s — show printed %s\n' "$1" "$2"
    FAILS=$((FAILS + 1))
  else
    printf '  ok    %s\n' "$1"
  fi
}

echo "--- a write inside an interval belongs to the subagent ---"
wrote "service.yaml"                      # before any agent: the main session
task_start spec-author
wrote "acceptance/cases/A-E1-01.yaml"
ran "checks/all.sh ."
task_end spec-author
wrote "state/build-state.yaml"            # after it returned: main again

expect_actor "a write before any Task"        "service.yaml"            main
expect_actor "a write inside the interval"    "A-E1-01.yaml"            spec-author
expect_actor "a command inside the interval"  "checks/all.sh"           spec-author
expect_actor "a write after the Task returned" "state/build-state.yaml" main

echo "--- SubagentStop never closes an interval ---"
: > "$AGENT_LOG"
task_start build-implementer
subagent_stop; subagent_stop; subagent_stop   # it fires dozens of times
wrote "target/src/main/java/App.java"
task_end build-implementer
expect_actor "a write after three spurious stops" "App.java" build-implementer
refute_show "the legacy stop rows stay out of the timeline" "■ stop"

echo "--- an interval that never closes is reported, not hidden ---"
: > "$AGENT_LOG"
task_start spec-author
wrote "specification/domain.md"
# no task_end: this is what every log written before the Task PostToolUse hook
# looks like, and the names after the start are not trustworthy
expect_show "unclosed interval warning" "never recorded an \`end\`"
wrote "a.md"; wrote "b.md"; wrote "c.md"; wrote "d.md"; wrote "e.md"
expect_show_limited "the warning survives -n, which scrolls the start away" \
  "never recorded an \`end\`"

echo "--- two agents at once is reported, not guessed ---"
: > "$AGENT_LOG"
task_start build-reviewer
task_start independent-advisor
wrote "reports/findings.md"
expect_show "overlap warning" "WARNING: two agents overlapped"

echo "--- the real log is untouched ---"
if [[ -n "${AGENT_LOG:-}" && "$AGENT_LOG" == "$WORK/"* ]]; then
  printf '  ok    every probe wrote to %s\n' "$AGENT_LOG"
else
  printf '  FAIL  AGENT_LOG escaped the scratch directory: %s\n' "${AGENT_LOG:-<unset>}"
  FAILS=$((FAILS + 1))
fi

echo
if (( FAILS == 0 )); then
  echo "PASSED  agent-log names the right agent on every line"
else
  echo "FAILED  $FAILS attribution case(s) came out wrong"
fi
exit $(( FAILS > 0 ))

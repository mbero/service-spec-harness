#!/usr/bin/env bash
# Proves that every check in this repository can actually fail.
#
# The rule it enforces on itself: a script that has never been observed
# reporting a violation is not a check, it is a comment. Five scripts in the
# harness this one is derived from once consisted of `set -euo pipefail` and a
# header — they exited 0 and reported a false pass on everything.
#
# Each case copies examples/vendor-task-service to a temporary directory,
# breaks it in exactly one way, runs the real check against the copy, and
# asserts two things: exit code 1, and that the output names the break. The
# second assertion matters as much as the first — a check that fails for an
# unrelated reason is not evidence.
#
# Usage: selftest.sh [-v]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
EXAMPLE="$ROOT/examples/vendor-task-service"
VERBOSE="${1:-}"

PASSED=0; FAILED=0
_g=''; _r=''; _off=''
if [[ -t 1 ]]; then _g=$'\033[32m'; _r=$'\033[31m'; _off=$'\033[0m'; fi

WORK=""
fresh() {
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/sshself.XXXXXX")"
  cp -R "$EXAMPLE/." "$WORK/"
  printf '%s' "$WORK"
}

# expect_fail <label> <needle> -- <command...>
expect_fail() {
  local label="$1" needle="$2"; shift 2
  [[ "${1:-}" == "--" ]] && shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  local why=""
  (( rc == 1 )) || why="expected exit 1, got $rc"
  if [[ -z "$why" ]] && ! grep -qF -- "$needle" <<< "$out"; then
    why="output never mentions: $needle"
  fi
  if [[ -z "$why" ]]; then
    PASSED=$((PASSED + 1))
    printf '%s  ok  %s%s\n' "$_g" "$label" "$_off"
    [[ "$VERBOSE" == "-v" ]] && printf '%s\n' "$out" | sed 's/^/        /'
  else
    FAILED=$((FAILED + 1))
    printf '%sFAIL  %s — %s%s\n' "$_r" "$label" "$why" "$_off"
    printf '%s\n' "$out" | sed 's/^/        /'
  fi
  [[ -n "$WORK" && "$WORK" == */sshself.* ]] && rm -rf "$WORK"
  WORK=""
  return 0
}

spec_check()    { "$HERE/spec-completeness.sh" "$1"; }
harness_check() { "$HERE/harness.sh" "$1"; }
arch_check()    { ARCH_FILE="$1/architecture.yaml" "$HERE/architecture.sh" "$1/target-sample"; }
tech_check()    { MANIFEST_FILE="$1/service.yaml" "$HERE/forbidden-tech.sh" "$1/target-sample"; }
secret_check()  { MANIFEST_FILE="$1/service.yaml" "$HERE/secrets.sh" "$1/target-sample"; }

printf '\n--- baseline: the untouched example is green ---\n'
for pair in "spec-completeness:spec_check" "architecture:arch_check" "forbidden-tech:tech_check"; do
  name="${pair%%:*}"; fn="${pair##*:}"
  if out="$("$fn" "$EXAMPLE" 2>&1)"; then
    PASSED=$((PASSED + 1)); printf '%s  ok  baseline %s%s\n' "$_g" "$name" "$_off"
  else
    FAILED=$((FAILED + 1))
    printf '%sFAIL  baseline %s is not green — every case below is meaningless%s\n' "$_r" "$name" "$_off"
    printf '%s\n' "$out" | sed 's/^/        /'
  fi
done

# ---------------------------------------------------------------------------
printf '\n--- spec-completeness ---\n'
# ---------------------------------------------------------------------------

W="$(fresh)"; perl -0777 -pi -e 's/^proves: \[E1-B03, GL-B01\]$/proves: [GL-B01]/m' "$W/acceptance/cases/A-E1-03.yaml"
expect_fail "an agreed behaviour nothing proves" \
  "E1-B03 is agreed but no acceptance case proves it" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/by: Marcin Berendt/by: spec-author agent/' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "an agent approving its own oracle" \
  "an acceptance case is approved by a person" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/status: approved/status: draft/' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "a behaviour proven only by a draft case" \
  "is proven only by draft cases" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's|json_exact: expected/A-E1-01.json|json_exact: expected/does-not-exist.json|' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "json_exact pointing at a missing file" \
  "points at a missing file" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/proves: \[E1-B01, GL-B01, GL-B02\]/proves: [E1-B99]/' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "a case proving a behaviour that does not exist" \
  "proves unknown behaviour E1-B99" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/"PD-002"/"obvious"/' "$W/specification/endpoints.yaml"
expect_fail "evidence that says nothing" \
  "says nothing" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/"PD-002"/"PD-404"/' "$W/specification/endpoints.yaml"
expect_fail "evidence citing a decision that was never recorded" \
  "which is not in decisions.yaml" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's|^    json_exact: expected/A-E1-01.json$|    json_exact: expected/A-E1-01.json\n    json_contains: { id: 7 }|m' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "a case that is laxer than it looks" \
  "it reads as stricter than it is" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/integration: I1/integration: I9/' "$W/acceptance/cases/A-E1-01.yaml"
expect_fail "a stub for an integration nobody specified" \
  "unknown integration I9" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^  - id: Q-001$/  - id: Q-009/m' "$W/gaps/open-questions.yaml"
expect_fail "an open behaviour whose question vanished" \
  "is not in gaps/open-questions.yaml" -- spec_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^        status: open$/        status: agreed/m' "$W/specification/endpoints.yaml"
expect_fail "an undecided behaviour quietly marked agreed" \
  "E2-B03" -- spec_check "$W"

# ---------------------------------------------------------------------------
printf '\n--- harness ---\n'
# ---------------------------------------------------------------------------

W="$(fresh)"; printf '{\n  "permissions": {\n    "deny": []\n  }\n}\n' > "$W/.claude/settings.json"
expect_fail "the deny rule protecting the oracle removed" \
  "permissions.deny has no Write(./acceptance/**) rule" -- harness_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^  - id: PD-002$/  - id: PD-003/m' "$W/decisions.yaml"
expect_fail "decisions.md and decisions.yaml drifting apart" \
  "disagree on the decision id set" -- harness_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^  mode: greenfield$/  mode: port/m' "$W/service.yaml"
expect_fail "port mode with no oracle to point at" \
  "the oracle is the whole point of that mode" -- harness_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^  tier: M$/  tier: S/m' "$W/service.yaml"
expect_fail "tier S still demanding an advisor it does not have" \
  "tier S declares advisor_review" -- harness_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^    - spec_completeness$//m' "$W/service.yaml"
expect_fail "the spec-completeness gate dropped from validation" \
  "omits spec_completeness" -- harness_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^  base: com.example.vendortask$/  base: <<REQUIRED — base package>>/m' "$W/architecture.yaml"
expect_fail "an unfilled marker left in a contract" \
  "unfilled marker" -- harness_check "$W"

# ---------------------------------------------------------------------------
printf '\n--- architecture ---\n'
# ---------------------------------------------------------------------------

DOMAIN='target-sample/src/main/java/com/example/vendortask/domain/model/Task.java'

W="$(fresh)"; perl -0777 -pi -e 's|^(package .*;)$|$1\n\nimport com.example.vendortask.infrastructure.config.JacksonConfig;|m' "$W/$DOMAIN"
expect_fail "domain reaching into infrastructure" \
  "AR-01" -- arch_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's|^(package .*;)$|$1\n\nimport org.springframework.web.bind.annotation.RestController;|m' "$W/$DOMAIN"
expect_fail "HTTP annotations in a domain type" \
  "AR-02" -- arch_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's|^(package .*;)$|$1\n\nimport com.example.vendortask.adapter.out.external.VendorRestAdapter;|m' \
  "$W/target-sample/src/main/java/com/example/vendortask/adapter/in/web/TaskController.java"
expect_fail "an inbound adapter calling an outbound one" \
  "AR-03" -- arch_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's/^import-rules:$/import-rules: []\nunused-rules:/m' "$W/architecture.yaml"
expect_fail "a contract with no rules left in it" \
  "this check would pass on anything" -- arch_check "$W"

# ---------------------------------------------------------------------------
printf '\n--- forbidden-tech / secrets ---\n'
# ---------------------------------------------------------------------------

W="$(fresh)"; perl -0777 -pi -e 's|^(package .*;)$|$1\n\nimport reactor.core.publisher.Mono;|m' \
  "$W/target-sample/src/main/java/com/example/vendortask/application/GetTaskUseCase.java"
expect_fail "a reactive type in a blocking service" \
  "reactive types in a blocking service" -- tech_check "$W"

W="$(fresh)"; perl -0777 -pi -e 's|<artifactId>spring-boot-starter-web</artifactId>|<artifactId>spring-boot-starter-webflux</artifactId>|' "$W/target-sample/pom.xml"
expect_fail "the reactive stack back on the classpath" \
  "not on the classpath" -- tech_check "$W"

W="$(fresh)"; printf 'class TestConstants {\n    static final String TOKEN = "eyJhbGciOiJSUzUxMiJ9.eyJzdWIiOiJ0ZXN0In0.c2lnbmF0dXJl";\n}\n' \
  > "$W/target-sample/src/main/java/com/example/vendortask/TestConstants.java"
expect_fail "a token pasted into a test constant" \
  "JWT literal" -- secret_check "$W"

# ---------------------------------------------------------------------------
printf '\n'
if (( FAILED > 0 )); then
  printf '%sFAILED%s  %d/%d selftest case(s) did not hold\n' "$_r" "$_off" "$FAILED" "$((PASSED + FAILED))" >&2
  exit 1
fi
printf '%sPASSED%s  %d selftest case(s): every check has been observed failing for its own reason\n' \
  "$_g" "$_off" "$PASSED"
exit 0

# `acceptance/` — the oracle

## The three directories

The spec-author creates each one on first write. They are empty in the
template, so git does not carry them.

| Path | Holds |
|---|---|
| `acceptance/cases/` | one file per case, named exactly `<id>.yaml`. Format below. |
| `acceptance/expected/` | expected response bodies, one `.json` per case that uses `then.body.json_exact` |
| `acceptance/fixtures/` | upstream response bodies, shared between cases via `given.upstream[].respond.body_file` |

**`expected/` is byte-for-byte**, field order included. Do not reformat a file
there; a formatter run is a silent contract change.

**`fixtures/` holds no secret and no real customer record.** A fixture that
needs a token uses the placeholder `{{token}}`, which the runner substitutes
per run.

A worked set is in `examples/partner-task-service/acceptance/`.
`checks/selftest.sh` mutates that set to prove every rule in
`checks/spec-completeness.sh` can actually fail.

In a migration harness the oracle is a recording: you run the old service and
keep what it said. **There is nothing to record here.** So the oracle is
*authored*, and that changes one thing fundamentally:

> An acceptance case is an **input** to implementation, never an output of it.

## The rule that makes this harness worth running

**The implementer never writes, edits or deletes anything under `acceptance/`.**

**A path rule is not what enforces it, and this file used to say it was.** A
`permissions.deny` on `acceptance/` restricts `Write` and `Edit` and nothing
else. `Bash` is not covered and every implementing agent has `Bash`, so one
redirection reaches the oracle and the path rule never sees it. Worse, the rule
blocked `spec-author` — the one agent that *must* write there — which pushed its
cases through shell heredocs: the oracle still changed, by the only route nobody
could see. The rule is gone, and `checks/harness.sh` now reports its **return**
as a violation.

What holds instead, in four places, deliberately overlapping:

1. `checks/oracle-integrity.sh` records one SHA-256 per file when a person
   approves the cases, and fails the build when the content moved without a new
   seal. It does not care which tool moved it. **This is the gate.**
2. `checks/harness.sh` fails if that seal is missing where cases exist, or if a
   path deny on `acceptance/` comes back.
3. `bin/oracle-guard`, a `PreToolUse` hook on `Bash`, refuses a shell command
   that would write here — so every oracle write goes through `Write` or `Edit`
   and lands in `reports/agent-log.tsv` where you can read it. This is friction,
   not a boundary: it reads text, so a determined caller gets past it, which is
   exactly why rule 1 does not depend on it.
   `checks/oracle-guard-cases.sh` runs the hook against both sides, so an
   over-eager refusal surfaces as a failing selftest case and not as a lost day.
4. `.claude/agents/build-implementer.md` states it, and
   `.claude/agents/build-reviewer.md` makes `git status --porcelain acceptance/`
   producing any output an automatic reject.

Without this rule an agent writes the code, writes the test that the code
passes, and reports green. That is not verification; it is the model agreeing
with itself. Everything else in this repository is ordinary scaffolding — this
rule is the reason it exists.

## Who writes the cases

The `spec-author` agent drafts them, a **human approves** them. A drafted case
has `approved: null` and is not usable as a gate. `checks/spec-completeness.sh`
reports unapproved cases; `checks/all.sh` fails on them once the plan starts.

## Layout

| | |
|---|---|
| `cases/A-E<n>-<nn>.yaml` | one case: stubs, the request, the expected answer |
| `expected/A-E<n>-<nn>.json` | a large expected body, when inlining it would hide the case |
| `fixtures/*.json` | upstream response bodies shared between cases |

## Case format

```yaml
id: A-E1-01                       # must match the filename
title: Returns the task with its partner name resolved
endpoint: E1                      # must exist in specification/endpoints.yaml
proves: [E1-B01, E1-B03, GL-B02]  # every id must exist. This is the link that
                                  # makes a behaviour verifiable.
status: approved                  # draft | approved
approved:
  by: Marcin Berendt              # a person, never an agent
  date: "2026-11-06"

given:
  upstream:
    - integration: I1             # must exist in specification/integrations.yaml
      request:
        method: GET
        path: /api/v1/partners/42
      respond:
        status: 200
        body_file: fixtures/partner-42.json
  state: []                       # rows/messages to seed, [] when stateless

when:
  method: GET
  path: /api/v1/tasks/7
  headers:
    Authorization: "Bearer {{token}}"
  query: {}
  body: null

then:
  status: 200
  headers:
    X-TRACE-ID: { present: true }
  body:
    json_exact: expected/A-E1-01.json
    # or, instead of json_exact:
    # json_contains: { id: 7, partner: { name: "ACME" } }
  absent_fields: [partner.address]   # absence is a contract. Assert it.
```

### `then.body` — pick exactly one

| Form | Use when |
|---|---|
| `json_exact` | the whole body is the contract — field order and absence included |
| `json_contains` | the case is about a few fields and the rest is covered elsewhere |

Using both in one case is a violation: it reads as stricter than it is.

### `absent_fields`

Listing a field here asserts it is **not present**, which is different from
present-and-null. When the service serialises with `NON_EMPTY`, this is the
only way to pin the difference, and it is the assertion teams omit.

## What a case may not do

- It may not reference the implementation: no class names, no package names, no
  SQL. A case that breaks when the code is refactored is testing the wrong
  thing.
- It may not be edited to make a failing step pass. That is the one change this
  harness is built to prevent; if a case is wrong, it is **re-approved by a
  human**, and the change is recorded as a `PD` entry saying what was wrong.

# Implementation status — read this first after a session restart

**As of 2026-11-06.** Everything below was run and observed, not assumed.

---

## Where the work stands in one paragraph

The harness is **complete and verified as scaffolding**, and **incomplete as a
build system**. The specification format, the acceptance-case format, every
gate, the self-test that proves the gates can fail, the five agent roles and
the worked example all exist and pass. What does not exist yet is the piece that
*executes* an acceptance case against a running service. Until that is written,
`acceptance_cases` in `service.yaml` `validation.required` is a promise rather
than a gate — see **Next step** below.

**The simplification is done.** `docs/simplification-plan.md` records the
decisions. The repository went from **82 tracked files to 62**, by merging
files only. No capability was removed. Every number below is the state after
that pass.

---

## Repository state

| | |
|---|---|
| Path | `/Users/marcinberendt/Priv_Repo/service-spec-harness` |
| Remote | `https://github.com/mbero/service-spec-harness.git` |
| Branch | `main` |
| Commits | `ce8b1e8` — the initial commit, 82 files, 4 526 insertions |
| Working tree | **dirty** — the simplification pass is uncommitted. 20 files deleted, ~25 modified, `docs/simplification-plan.md` added |
| Tracked files | 62, down from 82 |
| Python | `uv sync` has been run; `.venv/` and `uv.lock` exist (pyyaml 6.0.3) |

**Nothing has been pushed.** `origin` exists but has never received anything;
pushing needs its own go-ahead.

The initial commit carries **no ticket key**: this repository has no commit
history and no ticket prefix in its branch name, so there was no convention to
match and none was invented. The `<type>: [<KEY>] <subject>` form in
`service.yaml` is the convention the harness prescribes for the *services it
builds*, not for itself.

---

## Verify the state yourself — four commands

Run these before trusting anything in this file. Each one has been observed
producing exactly the output quoted.

```sh
cd /Users/marcinberendt/Priv_Repo/service-spec-harness

# 1. Every gate can actually fail, for its own reason
checks/selftest.sh
#    → PASSED  26 selftest case(s): every check has been observed failing for its own reason

# 2. The worked example is a valid, complete instantiation
E=examples/vendor-task-service
SPEC_ROOT=$E MANIFEST_FILE=$E/service.yaml ARCH_FILE=$E/architecture.yaml \
  TARGET=$E/target-sample checks/all.sh
#    → PASSED    [all] every stage green

# 3. The template itself fails — by design, on markers only
checks/harness.sh
#    → FAILED    [harness] 50 violation(s)   — all of them "unfilled marker"

# 4. No organisation-specific naming leaked into the template
#    Substitute your own org name, product names and ticket prefix:
grep -rniE '<org>|<product>|<TICKET-PREFIX>' . --exclude-dir=.git --exclude-dir=.venv
#    → no output (last swept 2026-11-06, clean)
```

Point 3 is **expected and correct**. The `<<REQUIRED — …>>` markers are what
make an unfilled field fail a check instead of rotting as a `TODO`. The template
is not an instantiation; `examples/vendor-task-service` is.

---

## What is finished

### The oracle layer — the reason the repository exists

- `acceptance/README.md` — the full case format, and the rule it enforces.
- Case schema: `id`, `endpoint`, `proves[]`, `status`, `approved{by,date}`,
  `given{upstream[],state[]}`, `when{}`, `then{status,headers,body,absent_fields}`.
- The write-deny on `acceptance/` is enforced in three overlapping places:
  `.claude/settings.json` `permissions.deny`, a `checks/harness.sh` assertion
  that the rule is still present and spelled correctly, and a mandatory reject
  condition in `.claude/agents/build-reviewer.md`.

### The gates — 8 scripts in `checks/`

| Script | Does |
|---|---|
| `spec-completeness.sh` | the new one. ~52 distinct violations across specification, cases, NFRs, gaps and the links between them |
| `architecture.sh` | layer rules read from `architecture.yaml` and executed — **no copy of the rules in bash** |
| `forbidden-tech.sh` | banned libraries, read from `service.yaml` `constraints.forbidden` |
| `secrets.sh` | credential tripwire over the harness and the target |
| `harness.sh` | the harness checks itself: unfilled markers, a deleted deny rule, a self-contradicting manifest, and **a check script the selftest never exercises** |
| `all.sh` | all of the above, aggregated; no `set -e`, so one run shows the whole picture |
| `selftest.sh` | 23 mutation cases + 3 baseline assertions = 26 |
| `_common.sh` | shared helpers; `MANIFEST_FILE` / `ARCH_FILE` / `SPEC_ROOT` overrides live here |

### Everything else

- `service.yaml` — manifest with `harness.mode` (greenfield / port / rewrite)
  and `harness.tier` (S / M / L), both consistency-checked.
- `specification/` — `endpoints.yaml`, `integrations.yaml`, `nfr.yaml`,
  `domain.md`. The id scheme and the `evidence` / `status` rules live in the
  header comments of `endpoints.yaml`.
- `gaps/open-questions.yaml` — the open-question register, treated as a
  deliverable; a question needs ≥2 options each with its consequence.
- `decisions.yaml` — the decision registry. One file, machine-readable; the
  entry format is documented in its header comments.
- `state/build-state.yaml` — the ledger and the one task in flight, in one
  file. There is no lock: one person builds one service at a time.
- `prompts/system.md` — the one shared prompt. Each role prompt lives inside
  its agent file under `.claude/agents/`.
- `.claude/` — five subagents, five slash commands, the deny rules.
- `examples/vendor-task-service/` — 1 endpoint, 7 behaviours, 1 upstream,
  3 approved cases, 1 deliberately open question, a clean Java sample under
  `target-sample/` so the code checks have something real to pass on.
- `docs/design-notes.md` — why it is shaped this way; what was dropped from the
  migration-harness ancestor and why.
- `docs/simplification-plan.md` — the 2026-11-06 grilling session: what was cut,
  what was deliberately left alone, and why.

---

## Next step — the acceptance runner

This is the one piece that closes the loop, and it is the first thing to build.

**What it must do:** take `acceptance/cases/A-*.yaml`, stand up stubs for the
upstreams in `given.upstream`, seed `given.state`, issue the single request in
`when`, and assert `then` — status, headers, `json_exact` byte-for-byte or
`json_contains`, and `absent_fields` as genuine absence rather than null.

**Suggested shape**, consistent with what is already here:

```
acceptance/
  run.sh              # driver: one case or all; BASE_URL + a stub port
  lib/run.py          # the comparison logic, via bin/py
```

**Constraints it must respect:**

- It runs through `bin/py` like everything else. Never `python3` directly.
- It must **never write** to `acceptance/` — it reads the oracle, it does not
  repair it. A case that does not match is a failure, never a case to update.
- `absent_fields` must distinguish absent from present-and-null. This is the
  assertion teams get wrong and the reason the field exists.
- Add a mutation case to `checks/selftest.sh` for it, or `checks/harness.sh`
  will fail — it refuses a check script the selftest never exercises.

After that, in rough order of value: a `/spec-init` interview to replace
copy-and-fill instantiation; shortened prompts for tier `S`; `port` / `rewrite`
mode support (record-then-replay), which is currently declared in the manifest
and checked for consistency but has no recorder behind it.

---

## Decisions taken during the build — do not re-litigate these

| Decision | Why |
|---|---|
| `<<REQUIRED — …>>` markers instead of `TODO` | a marker fails a check; a TODO rots. **A marker may never contain `: `** — that makes the YAML unparseable |
| `approved.date`, not `approved.on` | YAML 1.1 resolves a bare `on` key to the boolean `true`, so every approval silently read as empty |
| Architecture rules live only in `architecture.yaml` | the ancestor kept them in a contract *and* reimplemented them in bash; two copies, both edited |
| The worked example doubles as the selftest fixture | the example stays honest because breaking it breaks the test suite |
| The selftest asserts the **message**, not just exit 1 | a check failing for an unrelated reason is not evidence |
| No company-specific naming anywhere | explicit user instruction, 2026-11-06. Sample package is `com.example.vendortask` |

---

## Bugs found and fixed while building — all verified fixed

1. **`| consume_findings` ran the loop in a subshell.** Violation counters were
   discarded, so `spec-completeness.sh` reported `PASSED` on a broken
   specification. Now captured into a variable and fed via a here-string.
   The comment explaining this is in the script, deliberately.
2. **`<<REQUIRED: text>>` broke YAML parsing.** Colon-space is not legal in a
   plain scalar. Marker syntax changed to an em dash.
3. **`approved.on` parsed as the boolean `true`.** Field renamed to `date`.
4. **`secrets.sh` exited `2` on a template with no target configured.**
   `resolve_target` calls `exit 2`; inside `$( … || true )` the `true` never
   runs, and `set -e` killed the script. Now wrapped in an `if`. The practical
   effect was that `checks/all.sh` reported the `secrets` stage as failed
   instead of scanning the harness.
5. **The decisions format example used a real id (`## PD-001`).**
   `harness.sh` read it out of the fenced code block and reported the two
   registry files as disagreeing. Changed to `## PD-nnn`. The drift check that
   found it no longer exists — `decisions.md` and `decisions.yaml` are now one
   file, so there is nothing left to drift.

---

## How to resume

1. Read `README.md` — what the thing is and why.
2. Read `AGENTS.md` — the rules that are not negotiable when changing the
   template itself.
3. Run the four verification commands above.
4. Read `examples/vendor-task-service/` — faster than the format documentation.
5. Read `docs/simplification-plan.md` and answer its four open questions, or
   note that you are deferring them.
6. Pick up the acceptance runner.

If anything in this file disagrees with what the commands actually print,
**the commands are right and this file is stale.** Fix the file.

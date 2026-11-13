# Implementation status — read this first after a session restart

**As of 2026-11-09.** Everything below was run and observed, not assumed.

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
files only. No capability was removed.

**Three defects were found and fixed on 2026-11-08 and 2026-11-09**, all three
in the machinery that was supposed to make the harness trustworthy. Each one had
the same shape: a mechanism that looked like a guarantee and was not one. See
**Bugs found** below. The lesson is in `AGENTS.md`: a rule nobody has watched
fail is a rule you do not have.

---

## Repository state

| | |
|---|---|
| Path | `/Users/marcinberendt/Priv_Repo/service-spec-harness` |
| Remote | `https://github.com/mbero/service-spec-harness.git` |
| Branch | `main` |
| Commits | 7, head `32f1712`. `ce8b1e8` was the initial 82-file commit |
| Working tree | **clean** |
| Tracked files | 71 |
| Python | `uv sync` has been run; `.venv/` and `uv.lock` exist (pyyaml 6.0.3) |

**`origin/main` is at `32f1712`**, confirmed with `git ls-remote`. The
operator pushed it; no agent in this repository runs git.

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
#    → PASSED  43 selftest case(s): every check has been observed failing for its own reason

# 2. The worked example is a valid, complete instantiation
E=examples/partner-task-service
SPEC_ROOT=$E MANIFEST_FILE=$E/service.yaml ARCH_FILE=$E/architecture.yaml \
  TARGET=$E/target-sample checks/all.sh
#    → PASSED    [all] every stage green

# 3. The template itself fails — by design, on markers only
checks/harness.sh
#    → FAILED    [harness] 50 violation(s)   — all of them "unfilled marker"

# 4. No organisation-specific naming leaked into the template
#    Substitute your own org name, product names and ticket prefix:
grep -rniE '<org>|<product>|<TICKET-PREFIX>' . --exclude-dir=.git --exclude-dir=.venv
#    → no output (last swept 2026-11-09, clean)
```

Point 3 is **expected and correct**. The `<<REQUIRED — …>>` markers are what
make an unfilled field fail a check instead of rotting as a `TODO`. The template
is not an instantiation; `examples/partner-task-service` is.

---

## What is finished

### The oracle layer — the reason the repository exists

- `acceptance/README.md` — the full case format, and the rule it enforces.
- Case schema: `id`, `endpoint`, `proves[]`, `status`, `approved{by,date}`,
  `given{upstream[],state[]}`, `when{}`, `then{status,headers,body,absent_fields}`.
- The oracle is protected by **content**, not by a path rule. A
  `permissions.deny` entry covers `Write` and `Edit` and nothing else, and
  every implementing agent holds `Bash`, so the old deny on `acceptance/`
  blocked only `spec-author` — the one agent that must write there — and
  stopped no shell write at all. Removed in `3170af6`. What holds now:
  `checks/oracle-integrity.sh` (one SHA-256 per oracle file against a seal a
  person took — **the gate**), `bin/oracle-guard` (a `PreToolUse` hook that
  refuses a shell write, so the change stays visible in the log — friction,
  never a boundary), and `checks/harness.sh`, which fails if the seal is
  missing where cases exist **or if the deny rule comes back**.

### The gates — 11 scripts in `checks/`

| Script | Does |
|---|---|
| `spec-completeness.sh` | the new one. ~52 distinct violations across specification, cases, NFRs, gaps and the links between them |
| `architecture.sh` | layer rules read from `architecture.yaml` and executed — **no copy of the rules in bash** |
| `forbidden-tech.sh` | banned libraries, read from `service.yaml` `constraints.forbidden` |
| `secrets.sh` | credential tripwire over the harness and the target |
| `harness.sh` | the harness checks itself: unfilled markers, a deleted deny rule, a self-contradicting manifest, and **a check script the selftest never exercises** |
| `all.sh` | all of the above, aggregated; no `set -e`, so one run shows the whole picture |
| `oracle-integrity.sh` | hashes every file under `acceptance/`; `--seal` records the hashes after a person approves the cases. Tool-independent, so it catches a `Bash` heredoc the same as an `Edit` |
| `oracle-guard-cases.sh` | 36 probes at `bin/oracle-guard`: every shell write refused, every read and every heredoc body let through |
| `agent-log-cases.sh` | 9 probes at `bin/agent-log`: synthetic hook payloads in, the agent name on each rendered line asserted |
| `selftest.sh` | 31 mutation cases + 3 baseline assertions = 34 |
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
- `.claude/` — five subagents, seven slash commands, the `examples/**` deny
  rule, and the hooks that feed `bin/agent-log` and `bin/oracle-guard`. One
  command starts each agent; the other two are read-only. Each agent file names
  its **model**: `sonnet` for `build-implementer`, `opus` for the other four.
  `checks/harness.sh` fails if one of them names none.
- `bin/agent-log` — the run trace: which agent ran, in what order, what it
  wrote. Fed by hooks, not by the agents, so it records tool calls rather
  than an agent's account of them. Attribution is by **interval** — a write
  between `PreToolUse` and `PostToolUse` on one `Task` call belongs to that
  subagent, because the parent is blocked for exactly that span.
  `bin/agent-log show` renders it and warns when an interval never closed.
- `examples/partner-task-service/` — 1 endpoint, 7 behaviours, 1 upstream,
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
| No company-specific naming anywhere | explicit user instruction, 2026-11-06. Sample package is `com.example.partnertask` |
| The oracle is sealed by content, not denied by path | a path deny covers `Write` and `Edit` only. Every implementing agent holds `Bash`. The rule blocked the author and stopped nothing else — `3170af6` |
| `bin/oracle-guard` errs towards **allowing** | an allowlist of readers refused four harmless commands in one afternoon, and a false refusal teaches an agent to route around the guard. The hash is the gate, so the guard can afford to be permissive — `32f1712` |
| `build-implementer` runs on a cheaper model than its reviewers | its output passes `checks/all.sh` and the acceptance cases before anyone believes it. The four agents nothing checks stay on `opus`. A hard oracle is what lets you cheapen the generator — `32f1712` |

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

The next three were found on 2026-11-08 and 2026-11-09. Each one is a mechanism
that read as a guarantee and was not one, which makes them worth more words than
the five above.

6. **The deny rule on `acceptance/` protected nothing.** `permissions.deny`
   narrows `Write` and `Edit`. It does not narrow `Bash`, and every implementing
   agent holds `Bash`. The only agent the rule actually stopped was
   `spec-author`, whose job is to write the oracle — so that agent wrote 51
   cases through shell heredocs, and the oracle changed by the one route nobody
   could see. The documentation claimed the opposite in four places.
   Fixed in `3170af6`: the rule is gone, `checks/oracle-integrity.sh` hashes the
   oracle against a seal a person took, and `checks/harness.sh` now treats the
   deny rule's **return** as the violation.
7. **`bin/oracle-guard` refused four harmless commands in one afternoon** —
   including its own commit message, which merely named `acceptance/` in a
   heredoc body, and `du -sh acceptance`. It ran an allowlist of readers and
   denied everything unlisted. The tail of harmless commands has no end, and a
   false refusal is worse than a false allow here: it teaches an agent to route
   around the guard, which is the behaviour the guard exists to stop. Inverted
   in `32f1712` to deny the writing verbs, the redirections, the in-place flags
   and the writing `git` subcommands, and allow the rest.
   `checks/oracle-guard-cases.sh` holds it to both sides.
8. **The run log named the wrong agent.** It attributed work by hashing
   `transcript_path`, assuming a subagent reports its own transcript. On a real
   259-row log, all 259 rows carried **one** hash. `SubagentStop` was no help
   either — it fired **118 times for 2 subagents**. Every subagent write was
   therefore labelled `main`, and the one tool for seeing which agent did what
   was quietly useless. Fixed in `32f1712` by bracketing with `PreToolUse` and
   `PostToolUse` on `Task`: both fire in the parent, both carry
   `subagent_type`, and the parent is blocked for exactly that span.
   `checks/agent-log-cases.sh` proves the attribution.

All three had been *written down* as working. None had been *watched failing*.
That is the pattern, and `checks/*-cases.sh` is the answer to it.

---

## How to resume

1. Read `README.md` — what the thing is and why.
2. Read `AGENTS.md` — the rules that are not negotiable when changing the
   template itself.
3. Run the four verification commands above.
4. Read `examples/partner-task-service/` — faster than the format documentation.
5. Read `docs/simplification-plan.md` and answer its four open questions, or
   note that you are deferring them.
6. Pick up the acceptance runner. It is still the one missing piece, and it is
   now a decided one: the first instantiation of this template settled that the
   runner asserts the filesystem by **reading the disk**, not by trusting what
   the service reports, and that building the runner is step `S01` — the judge
   before the judged.

If anything in this file disagrees with what the commands actually print,
**the commands are right and this file is stale.** Fix the file.

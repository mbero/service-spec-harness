# Simplification plan — the grilling session of 2026-11-06

**Status: executed on 2026-11-06.** The repository went from **82 tracked
files to 62**. Every gate was re-run after each merge. Read this with
`docs/implementation-status.md`, which describes the repository as it stands
after the pass.

| Gate | Before | After |
|---|---|---|
| `checks/selftest.sh` | PASSED 27 | PASSED 26 — one case deleted on purpose |
| `checks/all.sh` on the example | PASSED, every stage green | unchanged |
| `checks/harness.sh` at the root | FAILED, 50 violations, markers only | unchanged |

---

## The question that started it

> Is this harness too complicated for what it does?

The harness builds **one microservice at a time**, from a **specification**,
through an agent loop. That is the whole job.

---

## The fact that frames every answer

**The harness has never built a service.**

| Evidence | Reading |
|---|---|
| `reports/plan/`, `reports/reviews/`, `reports/validation/` hold only `.gitkeep` | no run ever produced output |
| `state/build-state.yaml` says `steps_total: 0`, `steps: []` | no step ever landed |
| `specification.status: not_started` | no specification was ever agreed |
| only `examples/partner-task-service` is filled | it is a selftest fixture, not a run |

So the complexity is neither proven nor disproven. It is **untested**. About
3 300 lines of control exist against zero real runs.

This is why the plan below **merges files and removes no capability**. Until a
real build pushes back, nobody can tell ceremony from necessity.

---

## Settled

| # | Question | Answer |
|---|---|---|
| Q1 | Specification or reference implementation as the input? | **Specification.** No reference repository. |
| Q2 | How many services, how often, who? | **One at a time.** Single projects, one by one. |
| Q3 | Why does it feel too big? | **Too many files.** Judged by reading, not by a painful run. |
| Q4 | Install the Matt Pocock skill config here? | **No.** It would add a second convention beside the existing one. |
| Q5 | Keep the lock in `state/current-task.yaml`? | **Cut it.** One person and one project need no lock. |
| Q6 | What rule governs the cut? | **Merge only.** Every capability stays. |
| Q7 | Does `examples/` count in the file-count complaint? | **Yes.** 26 of 82 files sit there. |
| Q8 | Fold `current-task.yaml` into `build-state.yaml`? | **Yes.** One state file, not two. |
| Q9 | How to shrink `examples/` (26 files)? | **Trim it in place.** One endpoint, fewer Java classes. Not generated, not archived. |
| Q10 | How far to merge the explanation files? | **Fold every per-directory README** into the file or manifest it describes. |
| Q11 | Inline `prompts/` into `.claude/agents/`? | **Yes.** `prompts/system.md` stays shared and referenced by path. |
| Q12 | Approve the six small merges as one batch? | **Yes** — but see Q13 below. One of the six turned out to be a bad trade. |

---

## Correction — the real arithmetic

The first estimate said **82 → 47**. That was too optimistic. After reading
`checks/selftest.sh`, every `gaps/` reference and the example's endpoint tree,
the honest number is **82 → about 58**.

| Area | Removed | Why not more |
|---|---:|---|
| `examples/` | about 7 | the baseline must stay green; most files earn their place |
| per-directory READMEs | 7 | `acceptance/README.md` stays — it is the case format, and the template has no case file to host it |
| `prompts/` into `.claude/agents/` | 5 | `system.md` is shared by all five agents |
| `reports/*/.gitkeep` | 3 | agents create the directories instead |
| `state/current-task.yaml` | 1 | folded into the ledger |
| `decisions.yaml` | 1 | merged into `decisions.md` |
| `gaps/` move | **0** | a move is not a deletion — see Q13 |

**Total: about 24 files removed.**

---

## Round 6 — answered

### Q13 — leave `gaps/` where it is?

The Q12 batch included moving `gaps/open-questions.yaml` to
`specification/open-questions.yaml`. Measurement changed the picture:

- The path appears in **more than 20 places**: `checks/spec-completeness.sh`,
  `checks/selftest.sh`, `checks/_common.sh`, `prompts/system.md`,
  `prompts/spec.md`, `README.md`, `service.yaml`, `architecture.yaml`,
  `.claude/` agents and commands, and the example.
- The move removes **one directory and zero files**.

➡️ **Leave it.** Twenty edits for no file reduction is the worst trade in the
plan. This revokes one row of the Q12 batch; the other five stand.

### Q14 — which endpoint survives in the example?

The example specifies two: `E1` (a task lookup with a partner upstream) and
`E2`. `E2-B03` is the only behaviour with `status: open`, and `checks/selftest.sh`
line 121 depends on it.

- **(a) Keep `E1`.** Move the open behaviour in as `E1-B04`, still pointing at
  `Q-001`. Delete cases `A-E2-01` and `A-E2-02`.
- **(b) Keep `E2`.** Then rewrite the selftest cases that name `A-E1-01` and
  `A-E1-03`.

➡️ **(a).** The selftest already leans on `E1`. Keeping `E2` means rewriting
four selftest cases for nothing.

### Q15 — does 82 → 58 still justify the work?

The cut is real but smaller than the first estimate. The work touches `checks/`,
`prompts/`, `.claude/`, the manifests and the example together.

➡️ **Proceed** — and the session did. The strongest argument was not the file
count. It was that `prompts/` and `.claude/agents/` said the same thing twice.

---

## Rules this plan must not break

From `AGENTS.md`, unchanged by anything above:

- `acceptance/` is the oracle. The implementer may never write to it.
- No check ships without a matching case in `checks/selftest.sh` that seeds the
  violation and confirms exit `1`.
- Unfilled fields stay `<<REQUIRED — …>>` markers, never `TODO`.
- No agent runs git.

---

## How to resume

Every question is answered and every merge is done. What is left:

1. Review the working tree. Nothing is committed.
2. Build one real service with the harness. That run is the only thing that can
   tell ceremony from necessity — and it is what the Q6 "merge only" rule was
   waiting for.
3. Revisit `checks/`, the five agents and the five commands **after** that run,
   with evidence instead of a file count.


---

## What was actually done — 2026-11-06

Executed in eight steps, each followed by a full `checks/selftest.sh` run.

| Step | Change | Files |
|---|---|---:|
| A | `reports/` README and three `.gitkeep` deleted; the table moved into `AGENTS.md`. Agents create the directory on first write. | −4 |
| B | `state/current-task.yaml` and `state/README.md` folded into `state/build-state.yaml` as a `current:` section. The lock is gone. | −2 |
| C | `decisions.md` merged into `decisions.yaml`; the prose became header comments. The drift check in `checks/harness.sh` and its selftest case were deleted with it. | −2 |
| D | The three `acceptance/` sub-READMEs folded into `acceptance/README.md`. | −3 |
| E | `.claude/README.md` folded into `AGENTS.md`. | −1 |
| F | `specification/README.md` folded into the header comments of `specification/endpoints.yaml`. | −1 |
| G | Five role prompts inlined into their `.claude/agents/*.md` files. `prompts/system.md` stayed shared. | −5 |
| H | The example trimmed to one endpoint. `E2` removed; the open behaviour moved to `E1-B04` with `Q-001` rewritten to match. | −2 |

Plus `examples/partner-task-service/decisions.md`, removed with step C.
**Total: 20 files deleted, 0 capabilities removed.**

### What the trim could not reach

The first estimate said 58 files. The result is 62. The example gave up 3 files,
not 10: `checks/selftest.sh` and the `spec-completeness` baseline both need most
of what is there. All seven Java classes stayed — `TaskStatus` is used by `Task`,
and `JacksonConfig` is the example's only proof of `PD-001`.

### Left alone deliberately

- **`gaps/`** — see Q13. A move for zero file reduction.
- **`checks/` — all 8 scripts.** The harness has still never built a service,
  so no evidence says which gate is dead weight.
- **Five agents and five commands.** Same reason.

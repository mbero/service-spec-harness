# service-spec-harness

**A template for building a microservice from a written specification with AI
agents — and for knowing whether what came out is what was actually asked for.**

It is not a code generator and it is not a prompt. It is the scaffolding around
the model: a machine-readable specification, an acceptance oracle the
implementing agent is forbidden to touch, architecture rules that execute, a
decision registry, a work lock, and a review loop whose last gate is adversarial.

---

## The problem it exists to solve

Ask a model to build a service and you get three things: a service, its tests,
and a green test run.

The tests were written by the same run that wrote the code. So the green means
the model is consistent with itself. **It does not mean the service does what
you asked for**, and nothing in the output distinguishes the two cases.

That gap is tolerable when you can read every line of what came back. It stops
being tolerable at the size where you cannot — which is exactly the size at
which people reach for agents.

Three failure modes follow from it, and they are the ones this repository is
built around:

| Failure | What it looks like |
|---|---|
| **Invented requirement** | The spec is silent. The agent fills the silence, then asserts its invention in its own test. Nobody ever questions it again. |
| **Marking its own homework** | Code and oracle written by one run. Every subsequent "verified" claim inherits the flaw. |
| **Scope drift** | "A task service" quietly grows scheduling, notifications and an audit log that nobody asked for and no check can see. |

---

## The one idea

> **The agent that writes the code never writes the thing that proves the code.**

Everything else here is ordinary scaffolding. That rule is the product.

`acceptance/` holds the cases that define *done*. They are written **before**
implementation and approved by a **named human**.

**The guarantee is content, not a path rule.** A `permissions.deny` entry
restricts the `Write` and `Edit` tools and nothing else. `Bash` is not covered,
and every implementing agent has `Bash`, so one redirection reaches the oracle
and the path rule never sees it. This repository used to claim otherwise. It
does not any more, and the deny rule on `acceptance/` is gone — it blocked
`spec-author`, the one agent that must write there, and stopped nothing else.

What holds instead, in three places:

1. `checks/oracle-integrity.sh` records one SHA-256 per file when a person
   approves the cases, and fails the build when the content moved without a new
   seal. It does not care which tool moved it.
2. `checks/harness.sh` fails if that seal is missing where cases exist, or if a
   path deny on `acceptance/` comes back.
3. `bin/oracle-guard`, a `PreToolUse` hook, refuses a `Bash` command that would
   write there — so every oracle write goes through `Write` or `Edit` and lands
   in `reports/agent-log.tsv` where you can read it.
   `checks/oracle-guard-cases.sh` runs the hook against both sides, so an
   over-eager refusal shows up as a failing selftest case and not as a day lost.

Point 1 is the gate. Point 3 is friction: it reads text, so a determined caller
gets past it, and that is exactly why point 1 does not depend on it.

An approval whose `by:` field looks like an agent name is itself a violation,
reported by name.

---

## How it works

```
   ┌──────────────┐
   │ spec-author  │  elicits, drafts specification/ + acceptance/ + gaps/
   └──────┬───────┘  never writes service code
          │
          ▼  a human approves the cases, by name, in the file
   ┌──────────────┐
   │ orchestrator │  decomposes into ordered S01..Sxx steps
   └──────┬───────┘  refuses any step an open decision gates
          │
          ▼
   ┌──────────────┐
   │ implementer  │  builds exactly one step
   └──────┬───────┘  it may not change acceptance/; the seal catches it
          │
          ▼
   ┌──────────────┐     ┌──────────────────────┐
   │   reviewer   │ ──▶ │ independent advisor  │
   └──────────────┘     └──────────────────────┘
    re-runs every gate    tries to prove them both wrong
    itself, no Edit       read-only; one CRITICAL halts the build
```

Five roles, each with its own prompt and its own tool allowlist. The reviewer
and the advisor have **no `Edit`** — a reviewer that can fix what it finds ends
up reviewing its own work, and the loop loses its only independent signal.

Between them sits a set of gates that are not opinions:

- `checks/spec-completeness.sh` — is the specification complete enough to
  implement, and is **every agreed behaviour actually provable**?
- `checks/architecture.sh` — layer boundaries, read from `architecture.yaml` and
  executed. No second copy of the rules in a script to drift away from them.
- `checks/forbidden-tech.sh` — the banned-library list from the manifest.
- `checks/secrets.sh` — a tripwire for credentials reaching the repo.
- `checks/harness.sh` — the harness checks **itself**: coupled files that have
  drifted apart, unfilled fields, a deleted deny rule, a manifest that
  contradicts its own mode.

---

## What makes the specification different from a document

Every statement in `specification/` must be capable of being **shown false by
running something**. A statement that cannot fail is not a requirement.

- `"the API should be intuitive"` — cannot fail. Not a requirement.
- `"a GET for a task id that does not exist answers 404 with a problem+json
  body naming the requested id"` — can fail. Becomes acceptance case
  `A-E1-02`.

Three fields carry the weight:

| Field | Enforces |
|---|---|
| `evidence:` | where the requirement came from — a decision, an ADR, a dated conversation. `"obvious"` and `"standard REST"` are rejected by name, because in greenfield work an unsourced requirement is usually an invented one. |
| `status:` | `proposed` (a draft, **not implementable**) → `agreed` (a human approved it) → or `open`, which must point at a question in `gaps/`. |
| `proves:` | the link from an acceptance case back to the behaviours it pins. Checked in **both** directions: an agreed behaviour nothing proves is a violation. |

**`gaps/open-questions.yaml` is a deliverable, not a failure report.** The most
valuable thing this harness produces in its first week is an exact list of what
nobody has decided yet — written precisely enough that a product owner can
answer it in one sitting. Each question carries at least two options and the
consequence of each, or it does not count as a question.

### Every question the harness asks is written in ASD-STE100

A question this harness puts to a person is written in **Simplified Technical
English** (ASD-STE100), the aerospace maintenance-documentation standard. That
covers a `Q-nnn` in `gaps/open-questions.yaml`, the `question:` and `options:`
fields of a `PD-nnn` in `decisions.yaml`, and the question section of any
agent's report.

| Rule | Why it is here |
|---|---|
| One instruction per sentence, at most 20 words. A descriptive sentence, at most 25 | A long sentence hides a second question inside the first. The answer then covers only one of them |
| Active voice. Name the actor | "The file is read" leaves open *by what*. In this harness that is usually the whole question |
| Simple present, past or future only | A conditional chain describes a hypothetical. The reader must rebuild it before they can disagree with it |
| One term for one thing, every time | A synonym reads as a new concept. "Target", "destination" and "output repository" in one question produce an answer about the wrong one |
| No idiom, no metaphor, no humour | The reader may not share the writer's first language. A wrong reading becomes a wrong requirement |
| More than two items go in a vertical list | A sentence with four commas is a list the reader must parse |

**This is not a style preference.** Everything downstream of an answer is
mechanical: a behaviour becomes an acceptance case, a case becomes a gate, a
gate blocks a build. The question is the last point in that chain where a person
reads prose. It is therefore the last point where an ambiguity costs nothing to
catch. A misread question is paid for twice — once when the specification
records the wrong answer, and again when the gates enforce it faithfully.

The rule applies to the **question**, not to the specification around it.
`specification/domain.md` and the `evidence:` fields stay as long as they must
be. Correctness beats brevity: add a sentence rather than write a short one that
is false.

Nothing in `checks/` enforces this. It is a rule for whoever drafts the
question, person or agent, and `.claude/agents/spec-author.md` repeats it at the
point where the questions are written.

---

## What is in here

| Path | Holds |
|---|---|
| `service.yaml` | the manifest: mode, tier, repositories, constraints, agents, gates |
| `architecture.yaml` | layer boundaries as **executable** rules |
| `specification/` | endpoints, behaviours, integrations, non-functionals |
| `acceptance/` | **the oracle** — cases, expected bodies, upstream fixtures |
| `state/oracle-manifest.sha256` | the seal: one SHA-256 per oracle file, taken when a person approved it |
| `gaps/open-questions.yaml` | what nobody has decided yet |
| `decisions.yaml` | the decision registry — every decision an agent may not take alone |
| `checks/` | the gates, plus the selftest that proves each one can fail |
| `prompts/system.md` | the shared system prompt; each role prompt lives inside its agent file |
| `state/build-state.yaml` | the ledger: what has landed, and the one task in flight |
| `.claude/` | five subagents, seven slash commands, the deny rules, the hooks behind `/spec-log` |
| `examples/partner-task-service/` | a complete worked instantiation — and the selftest fixture |
| `docs/design-notes.md` | why it is shaped this way, and what was deliberately dropped |

---

## See it work before you fill anything in

```sh
uv sync                                          # once per clone (pyyaml on python3 also works)

checks/selftest.sh                               # 26 cases — the proof the gates are real
checks/spec-completeness.sh examples/partner-task-service
checks/all.sh                                    # see below for the env vars
```

`examples/partner-task-service` is a small but complete instantiation: one
endpoint, seven behaviours, one upstream, three approved cases, one deliberately
open question, and a clean Java sample for the code checks to pass on. Reading
it is faster than reading the format documentation.

---

## Tutorial — one service, from empty directory to reviewed code

### Step 0 — one copy of the template per service

This repository is a **template**. You do not run several services out of one
copy, and you do not point one copy at two target repositories. Each service
gets its own copy, because `service.yaml`, `specification/`, `acceptance/`,
`decisions.yaml` and `state/` all describe exactly one service and have nowhere
to put a second.

```sh
git clone https://github.com/mbero/service-spec-harness.git my-service-harness
cd my-service-harness
rm -rf .git && git init          # it is your repository now, not a fork of the template
uv sync                          # or: pip install pyyaml
```

Put the copy **next to** the service repository, not inside it. The harness is
versioned separately: it holds the specification and the oracle, and those
outlive any single branch of the service.

```
~/work/
  my-service/              <- the target repository, where code lands
  my-service-harness/      <- this copy
```

### Step 1 — prove the gates work before you trust them

```sh
checks/selftest.sh
```

26 cases must pass. Each one copies the worked example, breaks it in exactly one
way, and asserts the real check fails **naming that break**. Until you have seen
this pass, nothing else in this repository has earned belief.

```sh
checks/harness.sh                # MUST fail here: the markers are still in place
```

A fresh template fails its own check on purpose. That failure is the to-do list
for step 2.

### Step 2 — fill the manifest

Replace every `<<REQUIRED — …>>` marker in `service.yaml` and
`architecture.yaml`:

| Field | What to put |
|---|---|
| `project.name` | the service name |
| `project.description` | one paragraph, and say what the service is **not** responsible for |
| `repositories.target.path` | absolute path to the service repository |
| `repositories.target.branch` | the one branch all work lands on |
| `harness.mode` | `greenfield`, `port` or `rewrite` — see *Modes and tiers* |
| `harness.tier` | `S`, `M` or `L` |
| `constraints.forbidden` | each banned library, with the reason printed on violation |
| `architecture.yaml` → `package-layout.base` | the base package |

```sh
checks/harness.sh                # now exits 0
```

Restart your Claude Code session after this step. Hooks load when a session
starts, so `/spec-log` records nothing until you do.

### Step 3 — the commands, and what each one is responsible for

Seven commands. Five of them start an agent; two only read.

| Command | Starts | Writes | Responsible for |
|---|---|---|---|
| `/spec-status` | — | nothing | Telling you where the build stands. Safe first command in any session. |
| `/spec-elicit` | `spec-author` | `specification/`, `acceptance/`, `gaps/`, `decisions.yaml` | Turning your intention into behaviours and the cases that prove them — **and listing what it could not decide**. |
| `/spec-plan` | `build-orchestrator` | `reports/plan/`, `state/` | Cutting the specification into ordered steps `S01..Sxx`, and refusing to schedule what an open decision gates. |
| `/spec-next` | `build-implementer` | target code and tests, `state/` | Building **one** step. If it touches `acceptance/`, the seal breaks and the build goes red. |
| `/spec-review` | `build-reviewer`, then `independent-advisor` | `reports/reviews/` | Accepting or rejecting that step. The advisor runs second and tries to prove the reviewer missed something. |
| `/spec-check` | — | nothing | Running `checks/all.sh` — including `oracle-integrity` — and separating failures that belong to the step in flight from pre-existing ones. |
| `/spec-log` | — | nothing | Showing which agent ran, in what order, and what it wrote. |

`build-implementer` runs on `sonnet`; the other four run on `opus`. The
implementer writes the most code, and every line of it passes `checks/all.sh`
and the acceptance cases before anyone believes it. The other four define the
truth or exist to catch what an earlier agent missed, and nothing downstream
checks them. Change the mapping in `.claude/agents/*.md` — `checks/harness.sh`
fails if an agent file names no model at all.

### Step 4 — the loop, in order

```
  /spec-elicit  ──▶  YOU answer the questions  ──┐
        ▲                                        │
        └──────  more questions appear  ◀────────┘
                            │
                      YOU agree the behaviours
                      YOU approve the cases
                            │
                       /spec-plan
                            │
            ┌──────▶  /spec-next  ──▶  /spec-check  ──▶  /spec-review
            │                                                   │
            └───────────  YOU commit  ◀───────  accept ─────────┘
```

1. **`/spec-elicit`** — the author drafts and asks. Expect a second round: the
   first answers usually expose the next layer of questions.
2. **You answer.** Then set `status: agreed` on the behaviours you accept.
   Nothing is implementable while it is `proposed` or `open`.
3. **You approve the cases** — in `acceptance/cases/*.yaml`, with your own name
   in `approved.by`. An approver whose name looks like an agent is rejected by
   name. This is the step that makes the whole harness mean anything.

   Then **seal** them and commit the seal:

   ```sh
   checks/oracle-integrity.sh --seal
   git add state/oracle-manifest.sha256 acceptance/
   ```

   From here on, any change to `acceptance/` without a new seal turns
   `checks/all.sh` red — whichever tool made it. Seal again only after you
   approved what changed, never to make a red run green.
4. **`/spec-plan`** — the orchestrator produces `S01..Sxx`. It refuses to plan
   while `checks/spec-completeness.sh` is red, and it names what it could not
   schedule instead of planning around it.
5. **`/spec-next`** — one step. The implementer writes code and tests and runs
   that step's checks.
6. **`/spec-check`** — run the gates yourself rather than believing the report.
7. **`/spec-review`** — reviewer, then advisor, independently. A `CRITICAL`
   advisor finding halts the build.
8. **You commit.** No agent ever runs `git commit`, `git push` or
   `git checkout -b`. The implementer finishes on working-tree changes.
9. Back to 5 until `state/build-state.yaml` says every step landed.

### The three things only you can do

The harness is built so that an agent cannot do these, not merely so that it
should not:

| Gate | Why it is yours |
|---|---|
| Agreeing a behaviour | A `proposed` behaviour is the author's draft. An agent that could agree its own draft would be inventing requirements. |
| Approving a case | The oracle decides what *done* means. An agent that approved it would be marking its own homework. |
| Committing and pushing | Irreversible and visible to other people. |

### When something goes wrong

| Symptom | Where to look |
|---|---|
| `/spec-next` refuses | `state/build-state.yaml` → `current` is `in_progress` or `blocked`, or an `OPEN` decision in `decisions.yaml` blocks the step |
| `/spec-plan` refuses | `checks/spec-completeness.sh` is red — answer questions, do not plan around them |
| A check fails and you do not know whose fault it is | `/spec-check` splits it into *this step*, *pre-existing* and *harness* |
| You do not know what the agents actually did | `/spec-log` |
| `oracle-integrity` is red | somebody changed `acceptance/` after you sealed it. Read the diff before you re-seal; the step that produced it is void. |
| The ledger and reality disagree | `state/build-state.yaml` `steps:` is the fact; `current:` is only an intention |

---

## Modes and tiers

`harness.mode` — where truth comes from:

| Mode | Oracle |
|---|---|
| `greenfield` | the authored acceptance cases; there is nothing to record |
| `port` | a running service: record its answers, then replay them |
| `rewrite` | hybrid — the frozen part is recorded, the changed part is specified |

`harness.tier` — how much ceremony, because this is heavier than hand-writing
three CRUD endpoints and pretending otherwise helps nobody:

| Tier | Use for | Gets |
|---|---|---|
| `S` | ≤ 5 endpoints, no persistence | manifest, acceptance, checks. No phases, no advisor. |
| `M` | the normal case | the full loop: plan → implement → review → advise |
| `L` | behaviour deliberately changes partway through | phased contracts on top of `M` |

`checks/harness.sh` fails when the manifest contradicts itself — `greenfield`
with a reference repository configured, tier `S` demanding an advisor it does
not have, `port` mode with no oracle to point at.

---

## Why the checks are worth trusting

A check that has never been observed failing is not a check; it is a comment.

`checks/selftest.sh` copies the worked example, breaks it in **exactly one way**,
runs the real check against the broken copy, and asserts two things: that it
exits `1`, **and** that the output names that specific break. A check that fails
for an unrelated reason is not evidence, so the second assertion matters as much
as the first.

Thirty-four cases, including:

- an agreed behaviour that no case proves
- a case approved by an agent instead of a person
- a path deny on `acceptance/` coming back
- a case edited, added or deleted after a person sealed the oracle
- a `Bash` write to the oracle that `bin/oracle-guard` must refuse, and a
  commit message that merely names it, which it must let through
- `evidence: "obvious"`, and evidence citing a decision that was never recorded
- `domain` importing `infrastructure`; `@RestController` on a domain type
- an architecture contract with its rules emptied out
- a JWT pasted into a test constant

And then `checks/harness.sh` fails if any check script is **never exercised by
the selftest** — so "never ship a check that cannot fail" is itself enforced,
not merely written down.

---

## Honest limits

- **No acceptance runner yet.** The case format is complete and policed, but
  nothing in this repository yet *executes* a case against a running service
  (stub the upstreams, issue the request, diff the answer, assert the absent
  fields). Until that exists, `acceptance_cases` in `validation.required` is a
  promise rather than a gate. It is the next thing worth building.
- **A specification is thinner than running code.** A port harness reads every
  answer out of a working service. Here a human supplies them, and they will
  never be as dense — so the harness stops and asks, often and early. That cost
  is real; it is paid up front instead of in production.
- **On small work it is slower than just writing the service.** Tier `S` exists
  to say so honestly rather than to bury it in ceremony nobody runs twice.
- **It cannot tell you the specification is wrong** — only that the service
  matches it. Those are different things, and the second is all any tool can
  offer.

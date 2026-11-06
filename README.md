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
implementation, approved by a **named human**, and **denied to the implementing
agent at the permission layer**. The rule is enforced in three overlapping
places, because a rule enforced in one place is a rule that eventually gets
edited away:

1. `.claude/settings.json` → `permissions.deny` blocks every write to the path.
2. `checks/harness.sh` fails if that deny rule goes missing or gets misspelled.
3. `.claude/agents/build-reviewer.md` makes *"did this step touch `acceptance/`?"* an automatic
   reject, independent of how good the change looks.

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
   └──────┬───────┘  acceptance/ is write-denied to it
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

---

## What is in here

| Path | Holds |
|---|---|
| `service.yaml` | the manifest: mode, tier, repositories, constraints, agents, gates |
| `architecture.yaml` | layer boundaries as **executable** rules |
| `specification/` | endpoints, behaviours, integrations, non-functionals |
| `acceptance/` | **the oracle** — cases, expected bodies, upstream fixtures |
| `gaps/open-questions.yaml` | what nobody has decided yet |
| `decisions.yaml` | the decision registry — every decision an agent may not take alone |
| `checks/` | the gates, plus the selftest that proves each one can fail |
| `prompts/system.md` | the shared system prompt; each role prompt lives inside its agent file |
| `state/build-state.yaml` | the ledger: what has landed, and the one task in flight |
| `.claude/` | five subagents, five slash commands, the deny rules |
| `examples/vendor-task-service/` | a complete worked instantiation — and the selftest fixture |
| `docs/design-notes.md` | why it is shaped this way, and what was deliberately dropped |

---

## See it work before you fill anything in

```sh
uv sync                                          # once per clone (pyyaml on python3 also works)

checks/selftest.sh                               # 27 cases — the proof the gates are real
checks/spec-completeness.sh examples/vendor-task-service
checks/all.sh                                    # see below for the env vars
```

`examples/vendor-task-service` is a small but complete instantiation: two
endpoints, nine behaviours, one upstream, five approved cases, one deliberately
open question, and a clean Java sample for the code checks to pass on. Reading
it is faster than reading the format documentation.

### Then instantiate

1. Copy the repository next to the service you are building.
2. Replace every `<<REQUIRED — …>>` marker in `service.yaml` and
   `architecture.yaml`.
   **The template deliberately does not pass its own checks** —
   `checks/harness.sh` fails while a marker remains. An instantiation passes.
   (A marker is checked; a `TODO` comment rots silently. That is the whole
   reason for the convention.)
3. Run `/spec-elicit`. Answer the questions it returns. Answer them again after
   it finds the second layer.
4. **Approve the acceptance cases** — a person, by name, in the file.
5. Run `/spec-next`, then `/spec-review`. Repeat.

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

Twenty-seven cases, including:

- an agreed behaviour that no case proves
- a case approved by an agent instead of a person
- the deny rule protecting the oracle, removed
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

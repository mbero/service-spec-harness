# AGENTS.md — service-spec-harness

## What this repository is

A **template**, not a service. There is no production code here, no build and
no deployment. It is the scaffolding an AI agent needs in order to build a
microservice from a specification and to be *checked* while doing it.

Read `README.md` for the one idea. Read `prompts/system.md` before touching
anything — it binds every agent working in an instantiation, and the same rules
apply to anyone changing the template itself.

## Load order at the start of a session

1. **`docs/implementation-status.md`** — where the work actually stands, what is
   finished, what is next, and the commands that verify it. Read this first
   after any session restart.
2. `README.md` — what the thing is
3. `prompts/system.md` — the rules
4. `checks/selftest.sh` output — whether the machinery still works
5. `examples/partner-task-service/` — what a filled instantiation looks like

`docs/implementation-status.md` is a snapshot and goes stale. When it disagrees
with what the checks actually print, **the checks are right** — fix the file.

## The rules that are not negotiable

- **`acceptance/` is the oracle and the implementer may not write to it.** The
  guarantee is `checks/oracle-integrity.sh`, not a path rule — see *What is
  actually enforced*. If a change would weaken it — the seal made optional, the
  check dropped from `all.sh`, an approval field relaxed — it is the wrong
  change, whatever problem it solves.
- **Never ship a check that cannot fail.** Any change under `checks/` needs a
  matching case in `checks/selftest.sh` that seeds the violation and confirms
  exit `1` naming it. `checks/harness.sh` enforces this.
- **Markers, not TODOs.** An unfilled field is `<<REQUIRED — …>>`, which fails a
  check. A `TODO` comment rots silently. Do not introduce a second convention.
  A marker must never contain `: ` — that makes the YAML unparseable.
- **No agent runs git.** No commit, no branch, no push. Finish on working-tree
  changes and say they are ready.

## The template does not pass its own checks

`checks/harness.sh` fails at the repository root because the markers are still
in place. That is correct. Verification runs against
`examples/partner-task-service`, which is a complete instantiation, and against
the temporary copies `checks/selftest.sh` makes of it.

## `reports/` — output, not input

The directory is not tracked. An agent creates it on first write. Nothing in it
is a source of truth: `specification/`, `acceptance/`, `decisions.yaml` and
`state/` are.

| Path | Written by | Holds |
|---|---|---|
| `reports/plan/` | the orchestrator | `implementation-plan.md`, the ordered `Sxx` steps |
| `reports/reviews/` | the reviewer and the advisor | `Sxx.md`, `Sxx-advisor.md` — one pair per step |
| `reports/validation/` | the implementer | check output worth keeping, measurements, probe results |
| `reports/agent-log.tsv` | the hooks in `.claude/settings.json` | the run trace — `bin/agent-log show` renders it |

`state/oracle-manifest.sha256` is **not** in this table on purpose: it is
tracked, committed and read by a gate. Output it is not.

Keep a review report after the finding is fixed. The record of *what was nearly
shipped* is the most useful thing in that directory six weeks later.

## `.claude/` — the multi-agent wiring

`service.yaml` declares five agents. This directory is what makes them real.

| | |
|---|---|
| `agents/` | five subagents, each carrying its own role prompt and a tool allowlist |
| `commands/` | the slash commands that drive the loop — one per agent, plus the read-only ones |
| `settings.json` | the path denials, and the hooks that feed `bin/agent-log` |

The denials are the part that is enforced. The hooks are the part that is
observed: they fire on `Task`, on `Write`/`Edit`, on an interesting `Bash`, and
on `SubagentStop`, and they append to `reports/agent-log.tsv`. A hook never
blocks a tool call — `bin/agent-log hook` always exits `0`, because a logger
that can break the build gets deleted the first time it does.

Hooks are read when a session starts. A hook added mid-session records nothing
until the next one.

## The agents

Each agent file carries its own role prompt. `prompts/system.md` is the one
shared prompt, and every agent reads it first.

| Agent | Writes |
|---|---|
| `spec-author` | `specification/`, `acceptance/`, `gaps/`, `decisions.yaml` |
| `build-orchestrator` | `reports/plan/`, `state/`, `decisions.yaml` |
| `build-implementer` | the target code and its tests, `state/`, `reports/validation/` |
| `build-reviewer` | `reports/reviews/Sxx.md` only |
| `independent-advisor` | `reports/reviews/Sxx-advisor.md` only |

The reviewer and the advisor have **no `Edit`**, deliberately. A reviewer that
can fix what it finds ends up reviewing its own work, and the loop loses its
only independent signal.

`spec-author` and `build-implementer` are **never the same run**. The author
writes the oracle; the implementer is denied write access to it. If one agent
ever does both, this harness is decoration.

## What is actually enforced

Tool allowlists restrict *which tools*, never *which paths* — `Edit` reaches
any file on disk. A path rule in `settings.json` `permissions.deny` narrows
`Write` and `Edit`, and **nothing else**: `Bash` is not covered, and every
implementing agent has `Bash`.

| Denied | Why | What it does not stop |
|---|---|---|
| `examples/**` | the selftest fixture. Editing it to make `checks/selftest.sh` green removes the only proof the checks can fail. | a shell redirection |

**`acceptance/**` is deliberately NOT denied.** That rule blocked `spec-author`
— the one agent whose job is to write the oracle — and stopped no shell write
at all, so the author wrote 51 cases through `Bash` heredocs and the oracle
changed by the one route nobody could see. `checks/harness.sh` now fails if the
rule comes back.

The oracle is protected by content instead:

| Mechanism | Covers |
|---|---|
| `checks/oracle-integrity.sh` | every file under `acceptance/`, by SHA-256, against a seal a person took. Tool-independent. **This is the gate.** |
| `bin/oracle-guard` (`PreToolUse` on `Bash`) | the quiet route. Refuses a shell write so every oracle change goes through `Write`/`Edit` and into `reports/agent-log.tsv`. Reads text, so it is friction, never a boundary. `checks/oracle-guard-cases.sh` holds it to both sides: it refuses every shell write, and it lets through every read and every heredoc body that only names the oracle. |
| `checks/harness.sh` | the seal exists where cases exist; the deny rule has not returned; `examples/**` is still denied. |

An agent with `Bash` can also run `--seal` and re-record its own tampering.
What stops that is not a script: the manifest is committed, so a re-seal shows
up as a changed `state/oracle-manifest.sha256` in the diff you read before
committing — and no agent commits.

## The commands

| Command | Does | Agent |
|---|---|---|
| `/spec-status` | specification coverage, open questions, blocking decisions, the lock | none |
| `/spec-elicit` | runs the specification interview and writes the gaps it could not close | `spec-author` |
| `/spec-plan` | decomposes the specification into the ordered `S01..Sxx` steps | `build-orchestrator` |
| `/spec-next` | resolves the next step, refuses if blocked, claims the lock, delegates | `build-implementer` |
| `/spec-review` | reviewer, then advisor — independently, in that order | `build-reviewer`, `independent-advisor` |
| `/spec-check` | runs `checks/all.sh` and explains which failures belong to the step in flight | none |
| `/spec-log` | the run trace: which agent ran, in what order, and what it wrote | none |

Every agent has exactly one command that starts it. An agent with no command is
an agent nobody runs, and the gap is invisible until someone reads both lists.

`/spec-status` is a safe first command in any session: read-only, and it
surfaces the two things that invalidate everything downstream — an unapproved
oracle and a held lock.

## When you change the format

A format change usually touches four files at once. Change them together:

| Change | Also update |
|---|---|
| a field in a case | `acceptance/README.md`, `checks/spec-completeness.sh`, the example cases, `checks/selftest.sh` |
| a field in `specification/*.yaml` | the header comments in `specification/endpoints.yaml`, `checks/spec-completeness.sh`, the example, `.claude/agents/spec-author.md` |
| an architecture rule | `architecture.yaml` only — `checks/architecture.sh` reads it, nothing is hardcoded |
| a manifest field | `service.yaml`, `checks/harness.sh`, the example manifest |

Then run `checks/selftest.sh`. If it still passes 32/32 without you having
touched it, ask whether your change was actually covered.

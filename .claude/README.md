# `.claude/` — the multi-agent wiring

`service.yaml` declares five agents. This directory is what makes them real.

| | |
|---|---|
| `agents/` | five subagents, each bound to a `prompts/` file and a tool allowlist |
| `commands/` | the slash commands that drive the loop |
| `settings.json` | the path denials — the part that is actually enforced |

## The agents

| Agent | Prompt | Writes |
|---|---|---|
| `spec-author` | `system.md` + `spec.md` | `specification/`, `acceptance/`, `gaps/`, `decisions.md` |
| `build-orchestrator` | `system.md` + `plan.md` | `reports/plan/`, `state/`, `decisions.md` |
| `build-implementer` | `system.md` + `implement.md` | the target code and its tests, `state/`, `reports/validation/` |
| `build-reviewer` | `system.md` + `review.md` | `reports/reviews/Sxx.md` only |
| `independent-advisor` | `system.md` + `advisor.md` | `reports/reviews/Sxx-advisor.md` only |

The reviewer and the advisor have **no `Edit`**, deliberately. A reviewer that
can fix what it finds ends up reviewing its own work, and the loop loses its
only independent signal.

`spec-author` and `build-implementer` are **never the same run**. The author
writes the oracle; the implementer is denied write access to it. If one agent
ever does both, this harness is decoration.

## What is actually enforced

Tool allowlists restrict *which tools*, never *which paths* — `Edit` reaches
any file on disk. So the path rules live in `settings.json` `permissions.deny`:

| Denied | Why |
|---|---|
| `acceptance/**` | the oracle. An implementer that can edit a case can make any step pass. |
| `examples/**` | the selftest fixture. Editing it to make `checks/selftest.sh` green removes the only proof the checks can fail. |

`checks/harness.sh` re-reads this file and fails if either rule is missing. A
deny rule nobody verifies is a deny rule that quietly gets deleted.

## The commands

| Command | Does |
|---|---|
| `/spec-status` | specification coverage, open questions, blocking decisions, the lock |
| `/spec-next` | resolves the next step, refuses if blocked, claims the lock, delegates to the implementer |
| `/spec-review` | reviewer, then advisor — independently, in that order |
| `/spec-check` | runs `checks/all.sh` and explains which failures belong to the step in flight |
| `/spec-elicit` | runs the specification interview and writes the gaps it could not close |

`/spec-status` is a safe first command in any session: read-only, and it
surfaces the two things that invalidate everything downstream — an unapproved
oracle and a held lock.

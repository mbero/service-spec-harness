# `state/` — the lock and the ledger

Two files, two different jobs. They are confused constantly, so:

| File | Is | Answers |
|---|---|---|
| `current-task.yaml` | the **lock** | what is being worked on *right now*, by whom |
| `build-state.yaml` | the **ledger** | what has actually landed, ever |

**When they disagree, the ledger wins.** The lock describes an intention; the
ledger describes a fact. An agent that finds `current-task.yaml` claiming a step
is `in_progress` while `build-state.yaml` already records it as done is looking
at a dead lock — and reports it rather than resolving it.

## Why a lock at all

Two agents in one working tree is how a harness stops meaning anything: both
edit, both run the checks, and the result describes neither run. The lock is a
file because it has to survive a crashed agent, a closed terminal and a
restarted session.

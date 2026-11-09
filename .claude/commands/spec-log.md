---
description: The agent run log — which agent ran, in what order, and what it touched
argument-hint: "[-n N — show only the last N events]"
---

Read-only. Run `bin/agent-log show $ARGUMENTS` and print its output verbatim.

The log is fed by hooks in `.claude/settings.json`, so it records what the tools
actually did, not what an agent reported doing. `state/build-state.yaml` is the
ledger of landed `Sxx` steps; this is the trace of the session.

Then say, in no more than four lines:

- which agent holds the newest `▶` with no matching `■` — that one is still running
- whether any agent wrote outside what its row in `AGENTS.md` allows
- whether anything under `acceptance/` was written, and by which agent
- whether the overlap warning appeared

The second and third points are the reason this command exists. A `spec-author`
line writing target code, or any agent writing `acceptance/`, breaks the one
rule the harness is built on and is worth stopping the run for.

An empty log is normal after `/clear` or a new session, and after a hook change:
hooks are read when the session starts, so a hook added mid-session records
nothing until the next one.

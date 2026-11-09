---
description: Plan or re-plan the build — decompose the specification into the ordered S01..Sxx steps
argument-hint: "[area or step to re-plan, e.g. 'S07a onwards' — optional]"
---

Delegate to the `build-orchestrator` agent.

Before delegating, run `checks/spec-completeness.sh` yourself and report its exit
code in one line. The orchestrator refuses to plan while that check is red, so a
red run means the answer is `/spec-elicit`, not this command.

Give it: the area named in `$ARGUMENTS` (or the whole specification if empty),
the current `state/build-state.yaml`, and `decisions.yaml` so it does not
schedule a step an `OPEN` blocking decision gates.

Re-planning keeps published ids. `Sxx` numbers are stable: an inserted step is
`S07a`, never a renumbering. Review reports and `state/` quote them.

When it returns, report:

1. **The step list**, by id and title, with each step's dependencies.
2. **The first schedulable step** — the one `/spec-next` would pick.
3. **Everything it refused to schedule**, and what would unblock each one.
   This section is the deliverable. A plan that silently omits a blocked step
   reads as a complete plan and is not one.
4. Whether `state/build-state.yaml` changed, and how.

Never present a plan as ready while the orchestrator named a behaviour that is
not `agreed` or a case that is not `approved`.

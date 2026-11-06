---
description: Where the build stands — specification coverage, open questions, blocking decisions, the task in flight, check results
---

Read-only. Safe as the first command in any session: it surfaces the two things
that invalidate everything downstream — an unapproved oracle and a step left
in flight.

Report, in this order, and say plainly where a source was unreadable:

1. **The task in flight** — `current` in `state/build-state.yaml`: its id,
   `status` and `started_at`. Report a `blocked` entry and what would unblock
   it.
2. **Specification coverage** — run `checks/spec-completeness.sh` and quote its
   summary lines: endpoints, behaviours by status, cases, coverage, open
   questions.
3. **Open questions** — `gaps/open-questions.yaml`, those with `status: open`,
   with what each blocks.
4. **Blocking decisions** — `OPEN` entries in `decisions.yaml` with a non-empty
   `blocking` list.
5. **Plan progress** — `state/build-state.yaml`: steps done of total, and the
   next schedulable step.
6. **Working trees** — `git status --short` for the harness and the target.
   Call out any change under `acceptance/` explicitly.

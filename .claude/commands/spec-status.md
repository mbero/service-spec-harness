---
description: Where the build stands — specification coverage, open questions, blocking decisions, the lock, check results
---

Read-only. Safe as the first command in any session: it surfaces the two things
that invalidate everything downstream — an unapproved oracle and a held lock.

Report, in this order, and say plainly where a source was unreadable:

1. **The lock** — `state/current-task.yaml`: status, `claimed_by`, `claimed_at`,
   and whether it looks stale. Report a stale lock; never clear it.
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

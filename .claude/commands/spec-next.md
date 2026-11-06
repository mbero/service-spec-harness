---
description: Start the next build step — checks it is not blocked, records it, delegates to the implementer
argument-hint: "[Sxx — optional, defaults to the next schedulable step]"
---

1. Resolve the step: `$ARGUMENTS` if given, otherwise the first `todo` step in
   `state/build-state.yaml` whose dependencies are done.
2. **Refuse** and stop if any holds — say which, and what would unblock it:
   - `current` in `state/build-state.yaml` is `in_progress` or `blocked`
   - a decision in the step's `Decisions` row is `OPEN` with a blocking scope
   - a behaviour in its `Behaviours` row is not `agreed`
   - a case in its `Cases` row is not `approved`
   - `checks/spec-completeness.sh` is red
3. Write `current` in `state/build-state.yaml` with the step's scope and
   verification point.
4. Delegate to the `build-implementer` agent with the step text, the cases it
   must satisfy, and the files it may write.
5. Report what the implementer reported — including its failures, unedited.

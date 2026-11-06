# Decision registry

Every decision an agent is not allowed to take alone. `decisions.yaml` is the
machine-readable index of the same entries — `checks/harness.sh` fails if the
two disagree on the id set, because a registry that tooling and humans read
differently is worse than no registry.

## How an entry is used

- An agent that hits a **red** authority item (see `architecture.yaml`
  `agent-authority`) writes a new `PD-nnn` here with status `OPEN` and stops.
- `blocking: [...]` names what cannot be built until the entry is `DECIDED`.
  The orchestrator refuses to schedule a step whose behaviours depend on an
  open blocking entry.
- `specification/*.yaml` may cite an entry as `evidence: "PD-nnn"`.
  `checks/spec-completeness.sh` verifies the id exists.

## Entry format

```markdown
## PD-nnn — <title>

**Status:** OPEN | DECIDED
**Risk:** LOW | MEDIUM | HIGH | CRITICAL
**Authority:** yellow | red
**Blocks:** E1-B03, I1
**Raised:** 2026-11-06 by spec-author

**Question.** One paragraph, answerable.

**Evidence.** What is already known, with sources.

**Options.** Each with its consequence.

**Outcome.** Empty while OPEN. When DECIDED: what was decided, by whom, on what
date, and what it means for the implementation.
```

## Decisions

<!-- No decision has been recorded yet. The first one an agent raises goes here. -->

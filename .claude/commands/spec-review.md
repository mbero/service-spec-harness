---
description: Review an implemented step — reviewer first, then the adversarial advisor
argument-hint: "[Sxx — optional, defaults to the step in flight]"
---

Two agents, **in this order, independently**. Do not let the second see the
first's verdict before forming its own — pass it the step and the diff, not the
review.

1. `build-reviewer` → `reports/reviews/Sxx.md`
2. `independent-advisor` → `reports/reviews/Sxx-advisor.md`

Then report:

- both verdicts, side by side
- **every place they disagree**, which is the most informative part of the run
- whether anything under `acceptance/` changed during the step
- a single recommendation: accept, fix and re-review, or halt

A `CRITICAL` advisor finding halts the build. Say so plainly and do not propose
continuing around it.

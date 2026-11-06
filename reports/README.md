# `reports/`

Output, not input. Nothing here is a source of truth — `specification/`,
`acceptance/`, `decisions.md` and `state/` are.

| | Written by | Holds |
|---|---|---|
| `plan/` | the orchestrator | `implementation-plan.md`, the ordered `Sxx` steps |
| `reviews/` | the reviewer and the advisor | `Sxx.md`, `Sxx-advisor.md` — one pair per step |
| `validation/` | the implementer | check output worth keeping, measurements, probe results |

A review report is kept even after the finding is fixed. The record of *what
was nearly shipped* is the most useful thing in this directory six weeks later.

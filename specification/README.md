# `specification/` — what the service must do

This directory is the **forward** twin of what a migration harness calls
`inventory/`. A migration reads behaviour out of running code; here there is no
code to read, so every statement is sourced to a **human decision** instead of
to a `file:line`.

That difference is the reason `evidence:` is mandatory on every behaviour.
A behaviour with no evidence is not a requirement — it is an assumption an
agent made, and `checks/spec-completeness.sh` rejects it.

## Files

| File | Holds |
|---|---|
| `domain.md` | the vocabulary and the business rules, in prose, for humans |
| `endpoints.yaml` | the observable contract per operation — the machine-readable core |
| `integrations.yaml` | every upstream: transport, timeouts, retries, failure behaviour |
| `nfr.yaml` | limits, SLAs, metrics, security, logging |

## Identifier scheme

Stable once published. `acceptance/cases/*.yaml`, `reports/plan/`, review
reports and `decisions.md` all quote these, so they are **never renumbered**.
Insert `E3a`, not a shift of everything after `E3`.

| Id | Means |
|---|---|
| `E<n>` | one operation (one method + path) |
| `E<n>-B<nn>` | one observable behaviour of that operation |
| `GL-B<nn>` | a global behaviour — applies to every operation |
| `I<n>` | one upstream integration |
| `N<n>` | one non-functional requirement |
| `A-E<n>-<nn>` | an acceptance case (lives in `acceptance/cases/`) |
| `PD-<nnn>` | a decision (`decisions.md`) |
| `Q-<nnn>` | an open question (`gaps/open-questions.yaml`) |

## The `evidence` field

Every behaviour carries one. Accepted forms:

```yaml
evidence: "PD-004"                       # a decision taken in this harness
evidence: "ADR-7 §3"                     # a company architecture decision
evidence: "confluence:Listing API v2"    # a written source outside the repo
evidence: "interview 2026-11-06, M.B."   # a conversation, dated and attributed
```

**Not accepted:** `obvious`, `standard REST`, `as usual`, an empty string, or a
missing key. `checks/spec-completeness.sh` fails on all four. The point is not
bureaucracy: in greenfield work the single most expensive failure is an agent
inventing a requirement and then proving it against its own invention.

## The `status` field

```yaml
status: agreed       # a human has approved this. Implementable.
status: proposed     # written by the spec author, not yet approved. NOT implementable.
status: open         # the question is unresolved; must have `question: Q-nnn`
```

An implementer may only build behaviour that is `agreed`. The orchestrator may
not schedule a step whose behaviours are `proposed` or `open`.

## How this connects to `acceptance/`

A behaviour that no acceptance case lists under `proves:` is **unverifiable**,
and an unverifiable requirement is how a greenfield agent marks its own
homework. `checks/spec-completeness.sh` enforces the link in both directions:

- every `agreed` behaviour is proven by at least one case
- every case proves at least one behaviour that exists

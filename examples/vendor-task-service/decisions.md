# Decision registry — vendor-task-service (example)

Two decided entries, kept short. The point of the file in this example is that
`evidence: "PD-001"` in `specification/endpoints.yaml` resolves to something
real — `checks/spec-completeness.sh` verifies it does.

## PD-001 — Response serialization omits empty values

**Status:** DECIDED · **Risk:** MEDIUM · **Authority:** red
**Decided:** 2026-11-06 by Marcin Berendt

Jackson `NON_EMPTY`. Absence is therefore part of the contract and is asserted
explicitly by `absent_fields` in the acceptance cases.

## PD-002 — Behaviour when vendor-service is unavailable

**Status:** DECIDED · **Risk:** HIGH · **Authority:** red
**Decided:** 2026-11-06 by Marcin Berendt

Degrade rather than fail: 200 with the vendor object reduced to `id`. Rejected:
503 passthrough, which turns one upstream's incident into ours.

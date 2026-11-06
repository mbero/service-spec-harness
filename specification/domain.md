# Domain — vocabulary and business rules

Prose, for humans. The machine-readable contract is `endpoints.yaml`; this file
exists so that a reader understands *why* those behaviours are what they are.

Keep the two consistent by rule: **a business rule stated here that no
`E<n>-B<nn>` expresses is not implemented.** Prose does not reach the agents as
a requirement — only `endpoints.yaml` does.

## Vocabulary

| Term | Means | Not to be confused with |
|---|---|---|
| <<REQUIRED>> | <<REQUIRED>> | <<REQUIRED>> |

## Business rules

### BR-1 — <<REQUIRED: short name>>

<<REQUIRED: the rule, stated so that someone could disagree with it.>>

**Expressed by:** <<REQUIRED: behaviour ids, e.g. E1-B02, E2-B01>>
**Source:** <<REQUIRED: who decided this and when>>

## Explicitly out of scope

<<REQUIRED: what this service does NOT do. This section prevents more rework
than any other part of the specification — an agent asked to build "a task
service" will happily invent scheduling, notifications and an audit log.>>

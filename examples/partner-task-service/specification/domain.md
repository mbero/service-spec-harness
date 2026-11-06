# Domain — partner-task-service

## Vocabulary

| Term | Means | Not to be confused with |
|---|---|---|
| Task | A unit of work assigned to one partner | A job in the scheduler — this service never executes anything |
| Partner | The external company a task belongs to | A supplier record in ERP; this service holds only the id |

## Business rules

### BR-1 — A task always belongs to exactly one partner

A task without a `partnerId` cannot exist. The partner's *name* is not stored —
it is resolved per request, which is why a partner outage is a rendering
question (E1-B03) and not a data question.

**Expressed by:** E1-B01, E1-B03
**Source:** interview 2026-11-06, M.B.

### BR-2 — A partner name is a snapshot, not a live value

The name returned with a task is the name partner-service gave at read time.
Whether that read may come from a cache is undecided — see Q-001.

**Expressed by:** E1-B04 (open)
**Source:** interview 2026-11-06, M.B.

## Explicitly out of scope

- Scheduling or executing tasks. This service stores and serves them.
- Notifying partners. No mail, no Kafka producer, no webhook.
- Task history or audit. There is no `GET /tasks/{id}/history` and none is planned.

# Domain — vendor-task-service

## Vocabulary

| Term | Means | Not to be confused with |
|---|---|---|
| Task | A unit of work assigned to one vendor | A job in the scheduler — this service never executes anything |
| Vendor | The external company a task belongs to | A supplier record in ERP; this service holds only the id |
| externalRef | The caller's own identifier for a task | The task id, which this service assigns |

## Business rules

### BR-1 — A task always belongs to exactly one vendor

A task without a `vendorId` cannot exist. The vendor's *name* is not stored —
it is resolved per request, which is why a vendor outage is a rendering
question (E1-B03) and not a data question.

**Expressed by:** E1-B01, E1-B03
**Source:** interview 2026-11-06, M.B.

### BR-2 — A blank title is not a title

Leading and trailing whitespace is trimmed before the check, so a title of
spaces only is blank.

**Expressed by:** E2-B02
**Source:** ADR-9

## Explicitly out of scope

- Scheduling or executing tasks. This service stores and serves them.
- Notifying vendors. No mail, no Kafka producer, no webhook.
- Task history or audit. There is no `GET /tasks/{id}/history` and none is planned.

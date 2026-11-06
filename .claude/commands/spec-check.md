---
description: Run the gates and explain which failures belong to the step in flight
argument-hint: "[target path — optional]"
---

Run `checks/all.sh`, then `checks/selftest.sh` if anything under `checks/`
changed in this session.

Report each stage with its exit code, then separate the failures into:

- **belongs to the step in flight** — in `scope.files_allowed`, fix now
- **pre-existing** — already failing before this step; name it and leave it
- **harness** — a `checks/harness.sh` or `spec-completeness` violation, which is
  a specification or wiring problem, not a code one

Never summarise a red run as "mostly green". Quote the violation lines.

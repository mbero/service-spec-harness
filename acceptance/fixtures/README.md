# `acceptance/fixtures/`

Upstream response bodies, shared between cases via `given.upstream[].respond.body_file`.

Never a secret, never a real customer record. A fixture that needs a token uses
the placeholder `{{token}}`, which the runner substitutes per run.

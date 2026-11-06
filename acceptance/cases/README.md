# `acceptance/cases/`

One file per case, named exactly `<id>.yaml`. Format: `acceptance/README.md`.

A worked set is in `examples/vendor-task-service/acceptance/cases/`.
`checks/selftest.sh` mutates that set to prove every rule in
`checks/spec-completeness.sh` can actually fail.

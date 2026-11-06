# Example — `partner-task-service`

A complete, valid, deliberately small instantiation of the harness: one
operation, one upstream, three acceptance cases, one open question.

It exists for two reasons.

1. **It is the worked example.** Reading it is faster than reading the format
   documentation.
2. **It is the test fixture.** `checks/selftest.sh` copies it to a temporary
   directory, breaks it in one specific way at a time, and asserts the matching
   check reports exactly that break and exits `1`. A check that has never been
   observed failing is not a check, and this is how these ones earn the name.

Nothing here is deployed. `target-sample/` holds a small, clean Java service
so the code checks have something real to pass on; it is a fixture, not a
build.

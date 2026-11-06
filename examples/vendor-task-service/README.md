# Example — `vendor-task-service`

A complete, valid, deliberately small instantiation of the harness: two
operations, one upstream, five acceptance cases, one open question.

It exists for two reasons.

1. **It is the worked example.** Reading it is faster than reading the format
   documentation.
2. **It is the test fixture.** `checks/selftest.sh` copies it to a temporary
   directory, breaks it in one specific way at a time, and asserts the matching
   check reports exactly that break and exits `1`. A check that has never been
   observed failing is not a check, and this is how these ones earn the name.

Nothing here is deployed. There is no Java.

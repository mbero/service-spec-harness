---
description: Run the specification interview and write down what it could not close
argument-hint: "[area, e.g. 'the create endpoint' — optional]"
---

Delegate to the `spec-author` agent.

Give it: the area named in `$ARGUMENTS` (or the whole service if empty), the
current `specification/`, and the existing `gaps/open-questions.yaml` so it does
not re-ask an answered question.

Before delegating, state in one line what already exists, so the user can see
whether this is a first pass or an increment.

When it returns, surface its **questions section verbatim** to the user. That
section is the deliverable of this command — the specification files are the
by-product. Do not summarise the questions away.

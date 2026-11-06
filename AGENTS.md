# AGENTS.md — service-spec-harness

## What this repository is

A **template**, not a service. There is no production code here, no build and
no deployment. It is the scaffolding an AI agent needs in order to build a
microservice from a specification and to be *checked* while doing it.

Read `README.md` for the one idea. Read `prompts/system.md` before touching
anything — it binds every agent working in an instantiation, and the same rules
apply to anyone changing the template itself.

## Load order at the start of a session

1. **`docs/implementation-status.md`** — where the work actually stands, what is
   finished, what is next, and the commands that verify it. Read this first
   after any session restart.
2. `README.md` — what the thing is
3. `prompts/system.md` — the rules
4. `checks/selftest.sh` output — whether the machinery still works
5. `examples/vendor-task-service/` — what a filled instantiation looks like

`docs/implementation-status.md` is a snapshot and goes stale. When it disagrees
with what the checks actually print, **the checks are right** — fix the file.

## The rules that are not negotiable

- **`acceptance/` is the oracle and the implementer may not write to it.** If a
  change here would weaken that — a deny rule removed, a check relaxed, an
  approval field made optional — it is the wrong change, whatever problem it
  solves.
- **Never ship a check that cannot fail.** Any change under `checks/` needs a
  matching case in `checks/selftest.sh` that seeds the violation and confirms
  exit `1` naming it. `checks/harness.sh` enforces this.
- **Markers, not TODOs.** An unfilled field is `<<REQUIRED — …>>`, which fails a
  check. A `TODO` comment rots silently. Do not introduce a second convention.
  A marker must never contain `: ` — that makes the YAML unparseable.
- **No agent runs git.** No commit, no branch, no push. Finish on working-tree
  changes and say they are ready.

## The template does not pass its own checks

`checks/harness.sh` fails at the repository root because the markers are still
in place. That is correct. Verification runs against
`examples/vendor-task-service`, which is a complete instantiation, and against
the temporary copies `checks/selftest.sh` makes of it.

## When you change the format

A format change usually touches four files at once. Change them together:

| Change | Also update |
|---|---|
| a field in a case | `acceptance/README.md`, `checks/spec-completeness.sh`, the example cases, `checks/selftest.sh` |
| a field in `specification/*.yaml` | `specification/README.md`, `checks/spec-completeness.sh`, the example, `prompts/spec.md` |
| an architecture rule | `architecture.yaml` only — `checks/architecture.sh` reads it, nothing is hardcoded |
| a manifest field | `service.yaml`, `checks/harness.sh`, the example manifest |

Then run `checks/selftest.sh`. If it still passes 27/27 without you having
touched it, ask whether your change was actually covered.

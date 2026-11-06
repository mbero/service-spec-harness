# Design notes — why this is shaped the way it is

## It started as a migration harness

The direct ancestor of this repository is a harness for porting one service
from one language and framework to another. Roughly two thirds of what is here
came straight across: the lock protocol, the decision registry, the authority
model, the role prompts, the check helpers, the "never ship a check that cannot
fail" rule.

One third did not, and the same third is the reason this repository exists
separately.

## The one difference that matters: the oracle

| | Porting | Building from a specification |
|---|---|---|
| Source of truth | **running code** | **a person** |
| How the contract is obtained | read out of the source, cited as `file:line` | elicited, cited as a decision or a dated conversation |
| Completeness | guaranteed — the code always answers | impossible to guarantee |
| Parity oracle | recorded from the original, byte for byte | **authored, and therefore corruptible** |
| Typical stop | `CONFLICT` between two sources | `UNKNOWN` — nobody has decided |
| Worst failure | a behaviour changes silently | **an agent invents a requirement and proves it against its own invention** |

Copying a painting lets you hold the original beside your copy at any moment.
Painting from a written description gives you nothing to hold it against — so
the only possible check is whether the description was precise enough, and
whether the thing that checks it was written by someone other than the painter.

Everything distinctive here follows from that:

- `acceptance/` is an **input**, not a recording, and it is write-denied to the
  implementer.
- A case carries `approved.by` and `approved.date`, and an approver whose name
  looks like an agent is a violation by name.
- `evidence:` is mandatory and `"obvious"` is rejected, because in greenfield
  work an unsourced requirement is usually an invented one.
- `gaps/open-questions.yaml` is a first-class deliverable. The harness's most
  valuable early output is an exact list of what nobody has decided — written
  so a product owner can answer it in one sitting.

## What was deliberately dropped

| Dropped | Why |
|---|---|
| `inventory/` (reverse engineering) | nothing to reverse engineer |
| `golden/capture.sh` (record from the oracle) | nothing to record from |
| `compare/` (live A/B against the original) | nothing to compare against |
| language-pair mapping guides | no source language |

`port` and `rewrite` modes exist in `service.yaml` for the case where there
*is* something to record. The checks branch on `harness.mode`, and
`checks/harness.sh` fails if the mode and the reference repository disagree —
a greenfield build that quietly points at a reference repository would have
half its gates comparing against something nobody declared.

## Decisions worth knowing about

**Markers instead of TODOs.** The ancestor's bootstrap script generated files
containing `# TODO: define this`, while its own system prompt declared a
TODO-only file to be "the defect this harness was built to remove". The
generator contradicted the thing it generated. Here an unfilled field is
`<<REQUIRED — …>>` and `checks/harness.sh` fails while one remains. A marker
must never contain a colon followed by a space — that makes the YAML
unparseable, which is how this convention was discovered.

**Architecture rules live in YAML, executed by one script.** The ancestor kept
its layer rules in a contract file *and* reimplemented them in bash. Two copies,
one of them authoritative, both edited. Here `checks/architecture.sh` reads
`architecture.yaml` and has no rules of its own.

**`approved.date`, not `approved.on`.** YAML 1.1 resolves a bare `on` to the
boolean `true`, so `on: "2026-11-06"` silently becomes the key `True` and every
approval reads as empty. Found by the check, in its first run.

**The selftest is a first-class artefact.** Twenty-seven cases, each breaking
the worked example in exactly one way and asserting that the right check fails
for the right reason. `checks/harness.sh` fails if a check script is never
exercised by it, which makes "never ship a check that cannot fail" enforceable
rather than aspirational.

## Known costs

- **Specification density.** A port harness derives tens of kilobytes of
  behavioural contract from real code. A human-authored specification will not
  reach that, so the harness stops and asks — often, and early.
- **Overhead on small work.** For three CRUD endpoints this is more work than
  writing the service. `tier: S` exists to say so honestly rather than to hide
  it behind ceremony nobody runs twice.
- **A cold registry.** `decisions.md` starts empty. Its value accumulates; for
  the first two weeks of any build it is thinner than the comparison that
  inspired it.

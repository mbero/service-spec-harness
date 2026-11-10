#!/usr/bin/env bash
# Is the specification complete enough to implement, and is every agreed
# behaviour actually verifiable?
#
# This is the gate a migration harness does not need. There, the running source
# service answers every question and the recorded golden master proves every
# claim. Here the specification is the only oracle, so an UNVERIFIABLE
# requirement is the failure mode: the agent builds something, writes a test
# that agrees with it, and reports green.
#
# Usage: spec-completeness.sh [SPEC_ROOT]
#        SPEC_ROOT defaults to the harness root; an example or a copy under
#        test passes its own path.
set -euo pipefail
CHECK_NAME="spec-completeness"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

SPEC_ROOT="$(resolve_spec_root "${1:-}")"
note "spec root: $SPEC_ROOT"

if ! have_python; then
  violation "Python with PyYAML is required (bin/py); run 'uv sync' or install pyyaml"
  finish
fi

# Captured, not piped: a `| consume_findings` runs the loop in a subshell and
# every violation it counts is discarded, so the check reports PASSED on a
# failing specification. This bug is the reason the pipe is spelled out here.
FINDINGS="$("$PY" - "$SPEC_ROOT" "$HARNESS_ROOT" <<'PY'
import sys, os, re, glob
import yaml

root = sys.argv[1]
harness = sys.argv[2] if len(sys.argv) > 2 else root
out = []
def v(msg): out.append("VIOLATION|" + msg)
def n(msg): out.append("NOTE|" + msg)

def load(rel, required=True):
    p = os.path.join(root, rel)
    if not os.path.exists(p):
        if required:
            v(f"missing required file: {rel}")
        return None
    try:
        return yaml.safe_load(open(p)) or {}
    except Exception as exc:
        v(f"{rel} is not valid YAML: {exc}")
        return None

endpoints_doc   = load("specification/endpoints.yaml")
integrations_doc= load("specification/integrations.yaml", required=False)
nfr_doc         = load("specification/nfr.yaml", required=False)
gaps_doc        = load("gaps/open-questions.yaml", required=False)
decisions_doc   = load("decisions.yaml", required=False)

decision_ids = set()
if isinstance(decisions_doc, dict):
    for d in (decisions_doc.get("decisions") or []):
        if isinstance(d, dict) and d.get("id"):
            decision_ids.add(str(d["id"]).strip())

MARKER = re.compile(r"<<\s*REQUIRED")
VAGUE = {"obvious", "standard", "standard rest", "as usual", "tbd", "n/a", "none", "-"}
VALID_STATUS = {"agreed", "proposed", "open"}
AGENTISH = re.compile(r"\b(agent|claude|gpt|llm|copilot|bot)\b", re.I)

def text(x):
    return (x if isinstance(x, str) else "").strip()

# ---------------------------------------------------------------------------
# 1. Specification: shape, evidence, status
# ---------------------------------------------------------------------------

behaviours = {}          # id -> dict(status, where)
endpoint_ids = []

def check_behaviour(b, where, pattern):
    bid = text(b.get("id"))
    if not bid:
        v(f"{where}: a behaviour has no id")
        return
    if not pattern.match(bid):
        v(f"{where}: behaviour id '{bid}' does not match {pattern.pattern}")
    if bid in behaviours:
        v(f"duplicate behaviour id {bid} ({where} and {behaviours[bid]['where']})")
        return
    status = text(b.get("status")).lower()
    if status not in VALID_STATUS:
        v(f"{bid}: status '{b.get('status')}' is not one of {sorted(VALID_STATUS)}")
    behaviours[bid] = {"status": status, "where": where, "raw": b}

    for field in ("title", "observable"):
        val = text(b.get(field))
        if not val:
            v(f"{bid}: '{field}' is empty")
        elif MARKER.search(val):
            v(f"{bid}: '{field}' still carries a <<REQUIRED>> marker")

    ev = text(b.get("evidence"))
    if status == "agreed":
        if not ev:
            v(f"{bid}: status is agreed but evidence is missing — an agreed "
              f"behaviour names who decided it")
        elif MARKER.search(ev):
            v(f"{bid}: evidence still carries a <<REQUIRED>> marker")
        elif ev.lower() in VAGUE:
            v(f"{bid}: evidence '{ev}' says nothing — cite a PD, an ADR, a "
              f"document or a dated conversation")
        else:
            for pd in re.findall(r"PD-\d{3}", ev):
                if decisions_doc is not None and pd not in decision_ids:
                    v(f"{bid}: evidence cites {pd}, which is not in decisions.yaml")

    if status == "open":
        q = text(b.get("question"))
        if not q:
            v(f"{bid}: status is open but no `question: Q-nnn` is given")
        else:
            behaviours[bid]["question"] = q

if isinstance(endpoints_doc, dict):
    svc = text(endpoints_doc.get("service"))
    if not svc or MARKER.search(svc):
        v("specification/endpoints.yaml: `service` is not set")
    consumers = endpoints_doc.get("consumers") or []
    if not consumers or any(MARKER.search(text(c)) for c in consumers):
        v("specification/endpoints.yaml: `consumers` is not answered — "
          "'who calls this' is a requirement, not a formality")

    for b in (endpoints_doc.get("global") or []):
        check_behaviour(b, "global", re.compile(r"^GL-B\d{2}$"))

    eps = endpoints_doc.get("endpoints") or []
    if not eps:
        v("specification/endpoints.yaml: no endpoints defined")
    for e in eps:
        eid = text(e.get("id"))
        if not re.match(r"^E\d+[a-z]?$", eid):
            v(f"endpoint id '{eid}' does not match E<n>")
            continue
        if eid in endpoint_ids:
            v(f"duplicate endpoint id {eid}")
        endpoint_ids.append(eid)
        for field in ("method", "path", "summary", "auth"):
            val = text(e.get(field))
            if not val or MARKER.search(val):
                v(f"{eid}: '{field}' is not set")
        bs = e.get("behaviours") or []
        if not bs:
            v(f"{eid}: has no behaviours — an endpoint with no stated behaviour "
              f"cannot be implemented or verified")
        for b in bs:
            check_behaviour(b, eid, re.compile(rf"^{re.escape(eid)}-B\d{{2}}$"))

# ---------------------------------------------------------------------------
# 2. Integrations and NFRs
# ---------------------------------------------------------------------------

integration_ids = set()
if isinstance(integrations_doc, dict):
    for i in (integrations_doc.get("integrations") or []):
        iid = text(i.get("id"))
        if not re.match(r"^I\d+$", iid):
            v(f"integration id '{iid}' does not match I<n>")
            continue
        integration_ids.add(iid)
        if text(i.get("status")).lower() == "agreed":
            for path in (("timeouts", "connect_ms"), ("timeouts", "read_ms"),
                         ("retry", "attempts"), ("on_failure", "behaviour")):
                cur = i
                for k in path:
                    cur = (cur or {}).get(k) if isinstance(cur, dict) else None
                if cur is None or MARKER.search(text(cur)):
                    v(f"{iid}: {'.'.join(path)} is not set — an implementer "
                      f"will otherwise pick a default and nobody will notice")
            obs = text((i.get("on_failure") or {}).get("observable"))
            if not obs or MARKER.search(obs):
                v(f"{iid}: on_failure.observable is not stated — what the CALLER "
                  f"sees when this upstream is down is a requirement")
        for used in (i.get("used_by") or []):
            u = text(used)
            if u and not MARKER.search(u) and u not in endpoint_ids:
                v(f"{iid}: used_by names unknown endpoint {u}")

# ---------------------------------------------------------------------------
# 3. Acceptance cases
# ---------------------------------------------------------------------------

case_files = sorted(glob.glob(os.path.join(root, "acceptance", "cases", "*.yaml")))
cases = {}
proven = {}              # behaviour id -> [case ids]

for path in case_files:
    rel = os.path.relpath(path, root)
    base = os.path.basename(path)[:-5]
    try:
        c = yaml.safe_load(open(path)) or {}
    except Exception as exc:
        v(f"{rel} is not valid YAML: {exc}")
        continue

    cid = text(c.get("id"))
    if cid != base:
        v(f"{rel}: id '{cid}' does not match the filename '{base}'")
    if cid in cases:
        v(f"duplicate case id {cid}")
        continue
    cases[cid] = c

    for field in ("title", "endpoint", "status"):
        if not text(c.get(field)):
            v(f"{cid}: '{field}' is missing")
    for field in ("given", "when", "then"):
        if not isinstance(c.get(field), dict):
            v(f"{cid}: '{field}' is missing or not a mapping")

    ep = text(c.get("endpoint"))
    if ep and ep not in endpoint_ids:
        v(f"{cid}: endpoint '{ep}' is not in specification/endpoints.yaml")

    proves = c.get("proves") or []
    if not proves:
        v(f"{cid}: proves nothing — a case that is not linked to a behaviour "
          f"verifies nothing a reviewer can check")
    for bid in proves:
        bid = text(bid)
        if bid not in behaviours:
            v(f"{cid}: proves unknown behaviour {bid}")
            continue
        st = behaviours[bid]["status"]
        if st != "agreed":
            v(f"{cid}: proves {bid}, whose status is '{st}' — a behaviour that "
              f"is not agreed cannot be verified, only guessed")
        proven.setdefault(bid, []).append(cid)

    status = text(c.get("status")).lower()
    if status not in {"draft", "approved"}:
        v(f"{cid}: status '{c.get('status')}' is not draft or approved")
    if status == "approved":
        ap = c.get("approved") or {}
        by, on = text(ap.get("by")), text(ap.get("date"))
        if not by or not on:
            v(f"{cid}: status is approved but approved.by / approved.date is empty")
        elif AGENTISH.search(by):
            v(f"{cid}: approved.by is '{by}' — an acceptance case is approved by "
              f"a person. An agent approving its own oracle is the failure this "
              f"check exists for")

    # then.body: exactly one assertion form
    then = c.get("then") or {}
    if "status" not in then:
        v(f"{cid}: then.status is missing")
    body = then.get("body") or {}
    forms = [k for k in ("json_exact", "json_contains") if k in body]
    if len(forms) == 0:
        v(f"{cid}: then.body names neither json_exact nor json_contains")
    elif len(forms) > 1:
        v(f"{cid}: then.body uses {forms} together — it reads as stricter than "
          f"it is; pick one")
    if "json_exact" in body:
        ref = text(body["json_exact"])
        p = os.path.join(root, "acceptance", ref)
        if not os.path.exists(p):
            v(f"{cid}: then.body.json_exact points at a missing file: acceptance/{ref}")

    when = c.get("when") or {}
    for field in ("method", "path"):
        if not text(when.get(field)):
            v(f"{cid}: when.{field} is missing")

    given = c.get("given") or {}

    for up in (given.get("upstream") or []):
        iid = text(up.get("integration"))
        if iid and iid not in integration_ids:
            v(f"{cid}: given.upstream names unknown integration {iid}")

    # Every path a case points into acceptance/ must resolve to a file.
    #
    # Collect the references first, then check them in one place, because the
    # failure is the same failure whatever the key: nothing reads these values
    # until the runner tries to materialise them, so a single mistyped
    # character used to pass every gate and surface as a run-time error with
    # no case id attached to it.
    refs = []

    for i, up in enumerate(given.get("upstream") or []):
        # An HTTP stub names a response body; a tree stub names a manifest.
        bf = text(((up.get("respond") or {}).get("body_file")))
        if bf:
            refs.append((f"given.upstream[{i}].respond.body_file", bf))
        fx = text(up.get("fixture"))
        if fx:
            refs.append((f"given.upstream[{i}].fixture", fx))

    # One manifest per role, under whichever of the two keys names the role.
    for block in ("workspace", "external"):
        for role, fx in sorted((given.get(block) or {}).items()):
            fx = text(fx)
            if fx:
                refs.append((f"given.{block}.{role}", fx))

    # text_equals and json_equals name an expected document. equals_fixture and
    # path do not: they carry a `<role>:<path>` into a materialised tree, which
    # exists only at run time. The shape test keeps the two apart without
    # guessing — only a value rooted in one of the two oracle directories is a
    # claim about a file in this repository.
    for i, fs in enumerate(then.get("filesystem") or []):
        if not isinstance(fs, dict):
            continue
        for key in ("text_equals", "json_equals"):
            val = text(fs.get(key))
            if val.startswith(("fixtures/", "expected/")):
                refs.append((f"then.filesystem[{i}].{key}", val))

    for where, val in refs:
        if not os.path.exists(os.path.join(root, "acceptance", val)):
            v(f"{cid}: {where} does not exist: acceptance/{val}")

# ---------------------------------------------------------------------------
# 4. The link that matters: every agreed behaviour is verifiable
# ---------------------------------------------------------------------------

agreed = [b for b, d in behaviours.items() if d["status"] == "agreed"]
unproven = [b for b in agreed if b not in proven]
for b in sorted(unproven):
    v(f"{b} is agreed but no acceptance case proves it — it is unverifiable, "
      f"and an unverifiable requirement is marked green by whoever implements it")

unapproved_only = [b for b in agreed
                   if b in proven
                   and all(text(cases[c].get("status")).lower() != "approved"
                           for c in proven[b])]
for b in sorted(unapproved_only):
    v(f"{b} is proven only by draft cases ({', '.join(proven[b])}) — a draft "
      f"case is not an oracle until a person approves it")

# ---------------------------------------------------------------------------
# 5. NFR verified_by must resolve
# ---------------------------------------------------------------------------

if isinstance(nfr_doc, dict):
    for r in (nfr_doc.get("requirements") or []):
        rid = text(r.get("id"))
        if text(r.get("status")).lower() != "agreed":
            continue
        vb = text(r.get("verified_by"))
        if not vb or MARKER.search(vb):
            v(f"{rid}: verified_by is not set — an NFR nothing proves is a mood")
        elif vb in cases:
            pass
        elif any(os.path.exists(os.path.join(base, vb))
                 for base in (root, harness, os.getcwd())):
            pass
        else:
            v(f"{rid}: verified_by '{vb}' is neither a known case id nor an "
              f"existing file")

# ---------------------------------------------------------------------------
# 6. Open questions, in both directions
# ---------------------------------------------------------------------------

questions = {}
if isinstance(gaps_doc, dict):
    for q in (gaps_doc.get("questions") or []):
        qid = text(q.get("id"))
        if not re.match(r"^Q-\d{3}$", qid):
            v(f"question id '{qid}' does not match Q-nnn")
            continue
        questions[qid] = q
        for field in ("question", "why_it_matters", "status"):
            if not text(q.get(field)):
                v(f"{qid}: '{field}' is empty")
        opts = q.get("options") or []
        if len(opts) < 2:
            v(f"{qid}: fewer than two options — a question with one answer is a "
              f"decision that was never written down")
        for o in opts:
            if not text(o.get("consequence")):
                v(f"{qid}: option '{text(o.get('option'))}' states no consequence")
        for bid in (q.get("blocks") or []):
            bid = text(bid)
            if bid and bid not in behaviours:
                v(f"{qid}: blocks unknown behaviour {bid}")
            elif bid and behaviours[bid]["status"] != "open":
                v(f"{qid} is {text(q.get('status'))} and blocks {bid}, but {bid} "
                  f"is '{behaviours[bid]['status']}' — one of the two is stale")

for bid, d in behaviours.items():
    if d["status"] == "open":
        qid = d.get("question", "")
        if qid and qid not in questions:
            v(f"{bid}: question {qid} is not in gaps/open-questions.yaml")
        elif qid and text(questions[qid].get("status")).lower() != "open":
            v(f"{bid} is open but {qid} is '{questions[qid].get('status')}'")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

n(f"{len(endpoint_ids)} endpoint(s), {len(behaviours)} behaviour(s): "
  f"{len(agreed)} agreed, "
  f"{sum(1 for d in behaviours.values() if d['status']=='proposed')} proposed, "
  f"{sum(1 for d in behaviours.values() if d['status']=='open')} open")
n(f"{len(cases)} acceptance case(s), "
  f"{sum(1 for c in cases.values() if text(c.get('status')).lower()=='approved')} approved")
if agreed:
    n(f"coverage: {len(agreed)-len(unproven)}/{len(agreed)} agreed behaviours proven")
if questions:
    n(f"{sum(1 for q in questions.values() if text(q.get('status')).lower()=='open')} "
      f"open question(s) blocking work")

print("\n".join(out))
PY
)"
consume_findings <<< "$FINDINGS"

finish

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M043"
name: "Behavioral verifiers (SC-3/SC-4/SC-5) + phase-suite aggregator"
depends_on: ["T01", "T02"]
---

## Prerequisites

T01 and T02 are complete:

- `tests/fixtures/m043-cloudflare/<scenario>/*.response.json` exist
  (`bash tools/verify/m043-p02-fixtures-shape.sh` exits 0).
- `scripts/wiki/cloudflare-access-setup.sh` exists and supports the
  `M043_CF_FIXTURE_DIR` / `M043_CF_CAPTURE_DIR` fixture-replay seam
  (`bash tools/verify/m043-p02-provisioner-shape.sh` exits 0).

`jq` (`/usr/bin/jq`) is on the path.

**Placeholder-alignment contract (load-bearing).** The T01 fixtures use the
`<name>` placeholder for the Pages project name (so the `<name>.pages.dev` /
`*.<name>.pages.dev` domains in the recorded responses are placeholder-pure, no
secrets). The behavioral verifiers therefore invoke the provisioner with
`--project-name '<name>'` so the provisioner's computed
`DOMAIN="<name>.pages.dev"` matches the fixture's recorded domains exactly —
critical for the all-present idempotency match (`select(.domain == $d or
((.self_hosted_domains // []) | index($d)))`). Every behavioral verifier below
passes `--project-name '<name>' --domains 'example.com'`.

## Description

Author the three behavioral verifiers that drive the provisioner against the
recorded fixtures (SC-3 create-order, SC-4 idempotency, SC-5 diagnostics), plus
the `m043-p02-phase-suite.sh` aggregator over all five P02 gates. These are the
mechanical proofs of the phase Truths that require running the provisioner (Tier 3
behavioral — they execute `cloudflare-access-setup.sh` in fixture mode).

## Steps

1. Author `tools/verify/m043-p02-create-order.sh` (verbatim below).
2. Author `tools/verify/m043-p02-idempotency.sh` (verbatim below).
3. Author `tools/verify/m043-p02-diagnostics.sh` (verbatim below).
4. Author `tools/verify/m043-p02-phase-suite.sh` (verbatim below).
5. Run the verification commands.

### Verbatim verifier: `tools/verify/m043-p02-create-order.sh`
```bash
#!/usr/bin/env bash
# m043-p02-create-order.sh — SC-3 (FR-6/FR-8): against the clean-account fixture
# the provisioner creates resources in Pages-project -> Access-app -> policy
# order, and the captured Access-app create body carries BOTH apex and wildcard
# self_hosted_domains. Behavioral — runs the provisioner in fixture-replay mode.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
FX="tests/fixtures/m043-cloudflare/clean-account"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

CAP="$(mktemp -d 2>/dev/null || echo /tmp/m043cap.$$)"
mkdir -p "$CAP"

M043_CF_FIXTURE_DIR="$FX" M043_CF_CAPTURE_DIR="$CAP" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$CAP/out.log" 2>&1
rc=$?
[ "$rc" -eq 0 ]
check "provisioner exits 0 on clean account (rc=$rc)" $?

ORDER="$(grep -E 'pages-project-create|access-app-create|access-policy-create' "$CAP/requests.log" 2>/dev/null | awk '{print $2}' | tr '\n' ',')"
[ "$ORDER" = "pages-project-create,access-app-create,access-policy-create," ]
check "create order is pages-project -> access-app -> policy (got: $ORDER)" $?

APPREQ="$CAP/access-app-create.request.json"
test -f "$APPREQ"
check "app-create request body captured" $?
if [ -f "$APPREQ" ]; then
  jq -e '.self_hosted_domains | index("<name>.pages.dev")' "$APPREQ" >/dev/null 2>&1
  check "app-create body has apex self_hosted_domain" $?
  jq -e '.self_hosted_domains | index("*.<name>.pages.dev")' "$APPREQ" >/dev/null 2>&1
  check "app-create body has wildcard self_hosted_domain" $?
fi

rm -rf "$CAP"
echo "SUMMARY: m043-p02-create-order.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Verbatim verifier: `tools/verify/m043-p02-idempotency.sh`
```bash
#!/usr/bin/env bash
# m043-p02-idempotency.sh — SC-4 (FR-7): against the all-present fixture the
# provisioner issues zero create requests and exits 0. Behavioral.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
FX="tests/fixtures/m043-cloudflare/all-present"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

CAP="$(mktemp -d 2>/dev/null || echo /tmp/m043cap2.$$)"
mkdir -p "$CAP"

M043_CF_FIXTURE_DIR="$FX" M043_CF_CAPTURE_DIR="$CAP" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$CAP/out.log" 2>&1
rc=$?
[ "$rc" -eq 0 ]
check "provisioner exits 0 on all-present account (rc=$rc)" $?

if grep -q -- '-create' "$CAP/requests.log" 2>/dev/null; then has_create=1; else has_create=0; fi
[ "$has_create" -eq 0 ]
check "zero create requests issued (idempotent re-run)" $?

rm -rf "$CAP"
echo "SUMMARY: m043-p02-idempotency.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Verbatim verifier: `tools/verify/m043-p02-diagnostics.sh`
```bash
#!/usr/bin/env bash
# m043-p02-diagnostics.sh — SC-5 (FR-9): the zero-trust-not-enabled fixture yields
# a non-zero exit + the dashboard-enablement instruction; the missing-scope
# fixture yields a non-zero exit + the scope-specific diagnostic. The two
# diagnostics are distinct (FR-9 distinguishable). Behavioral.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
S="scripts/wiki/cloudflare-access-setup.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/m043diag.$$)"
mkdir -p "$TMP"

# --- zero-trust-not-enabled ---
M043_CF_FIXTURE_DIR="tests/fixtures/m043-cloudflare/zero-trust-not-enabled" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$TMP/zt.log" 2>&1
zt_rc=$?
[ "$zt_rc" -ne 0 ]
check "zero-trust fixture exits non-zero (rc=$zt_rc)" $?
grep -qi 'zero trust' "$TMP/zt.log"
check "zero-trust diagnostic names Zero Trust" $?
grep -qi 'dashboard' "$TMP/zt.log"
check "zero-trust diagnostic names the dashboard-enablement step" $?

# --- missing-scope ---
M043_CF_FIXTURE_DIR="tests/fixtures/m043-cloudflare/missing-scope" \
  bash "$S" --project-name '<name>' --domains 'example.com' >"$TMP/ms.log" 2>&1
ms_rc=$?
[ "$ms_rc" -ne 0 ]
check "missing-scope fixture exits non-zero (rc=$ms_rc)" $?
grep -qi 'Apps and Policies' "$TMP/ms.log"
check "missing-scope diagnostic names the Access: Apps and Policies scope" $?
grep -qi 'permission' "$TMP/ms.log"
check "missing-scope diagnostic names the missing permission" $?

# --- distinguishability: zero-trust log must NOT carry the scope text, and
#     missing-scope log must NOT carry the zero-trust text ---
if grep -qi 'Apps and Policies' "$TMP/zt.log"; then d1=1; else d1=0; fi
[ "$d1" -eq 0 ]
check "zero-trust diagnostic is distinct from the scope diagnostic" $?
if grep -qi 'zero trust' "$TMP/ms.log"; then d2=1; else d2=0; fi
[ "$d2" -eq 0 ]
check "missing-scope diagnostic is distinct from the zero-trust diagnostic" $?

rm -rf "$TMP"
echo "SUMMARY: m043-p02-diagnostics.sh fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Verbatim verifier: `tools/verify/m043-p02-phase-suite.sh`
```bash
#!/usr/bin/env bash
# m043-p02-phase-suite.sh — P02 phase-suite aggregator. Runs all five P02 gates
# in order, exits 0 iff all pass, emits one SUMMARY line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2

pass=0
fail=0
run_gate() {
  if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
}

run_gate "tools/verify/m043-p02-fixtures-shape.sh"
run_gate "tools/verify/m043-p02-provisioner-shape.sh"
run_gate "tools/verify/m043-p02-create-order.sh"
run_gate "tools/verify/m043-p02-idempotency.sh"
run_gate "tools/verify/m043-p02-diagnostics.sh"

echo "SUMMARY: m043-p02-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

## Must-Haves

- Against the clean-account fixture the provisioner creates resources in
  Pages-project → Access-app → policy order with apex+wildcard `self_hosted_domains`
  (phase Truth 3 / SC-3).
- A second run against the all-present fixture issues zero creates and exits 0
  (phase Truth 4 / SC-4).
- The zero-trust and missing-scope fixtures each exit non-zero with a distinct,
  actionable diagnostic (phase Truth 5 / SC-5).
- `tools/verify/m043-p02-phase-suite.sh` aggregates all five P02 gates (phase
  Artifact + Key Link).

## Verification

`bash tools/verify/m043-p02-create-order.sh`

`bash tools/verify/m043-p02-idempotency.sh`

`bash tools/verify/m043-p02-diagnostics.sh`

`bash tools/verify/m043-p02-phase-suite.sh`

## Inputs

### From Previous Tasks

- `scripts/wiki/cloudflare-access-setup.sh` (from T02)
  - Key contract: invoked as
    `M043_CF_FIXTURE_DIR=<scenario> M043_CF_CAPTURE_DIR=<dir> bash <script>
    --project-name '<name>' --domains 'example.com'`. In capture mode it writes
    `<dir>/requests.log` (one `<METHOD> <ENDPOINT_KEY>` line per call) and
    `<dir>/<ENDPOINT_KEY>.request.json` (each create-call body). Exit codes: 0 ok;
    4 zero-trust-not-enabled; 5 missing-scope. Diagnostics print to stderr.
- `tests/fixtures/m043-cloudflare/{clean-account,all-present,zero-trust-not-enabled,missing-scope}/`
  (from T01) — the recorded responses each verifier replays.

### From Disk (Pre-existing)

- `tools/verify/m043-p01-phase-suite.sh` — the P01 aggregator this mirrors
  (same `run_gate` shape + `SUMMARY: ... pass=N fail=N` line).

## Constraints

- Every behavioral verifier passes `--project-name '<name>'` to align the
  provisioner's computed domain with the placeholder fixtures (see the
  Placeholder-alignment contract in Prerequisites). Changing the fixture project
  placeholder requires updating these flags in lockstep.
- Verifiers clean up their temp capture dirs (`rm -rf`) so repeated runs are
  deterministic.
- Path discipline: all four are project-owned, milestone-prefixed per-phase
  verifiers → `tools/verify/m043-p02-*.sh`.
- The phase-suite must NOT include itself (no recursion) and must NOT be cited as
  a Truth `Check:` in the phase plan (it is the aggregator, run separately).

## Expected Output

Each of the three behavioral verifiers prints `PASS:` lines and a
`SUMMARY: <name> fail=0`, exiting 0.
`bash tools/verify/m043-p02-phase-suite.sh` prints the five gates' output followed
by `SUMMARY: m043-p02-phase-suite.sh pass=5 fail=0`, exiting 0.

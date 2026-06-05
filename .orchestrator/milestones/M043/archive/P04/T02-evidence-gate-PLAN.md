---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M043"
name: "Evidence template + mechanical gate + fixtures"
depends_on: []
---

## Prerequisites

No upstream task dependency inside P04 (T02 is independent of T01). It mirrors the
M033 `validate-report.sh` mechanical-gate convention. Confirm the model file
exists before authoring (Plan-Time Discipline rule 1):

- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` exists (the
  awk-frontmatter-parsing, Bash-3.2, no-jq gate to model on).
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` exists (the
  structured-capture-form model).

## Description

Author the machine-checkable half of the US-4 pass:

1. **`tests/m043-acceptance/live-deploy/evidence-template.md`** — the structured
   capture form the tester copies to `evidence/<DATE>.md` and fills in.
2. **`tests/m043-acceptance/live-deploy/validate-evidence.sh`** — the SC-9
   mechanical gate. Exits 0 iff the evidence note records EITHER a completed live
   pass OR a signed deferred-validation acknowledgment.
3. **Two fixtures** under `tests/m043-acceptance/live-deploy/fixtures/`
   (`evidence-pass.md`, `evidence-deferred.md`) — well-shaped examples that the
   T03 `m043-p04-evidence-gate.sh` verifier drives the validator against.

The gate encodes SC-9's "or" semantics directly: SC-9 closes either by a verified
live deploy (the triad) OR by a signed deferred-validation note. This is distinct
from M033, where the deferred/skip override lived in `validate-milestone.sh`;
M043's SC-9 names the deferred note as a first-class valid closing artifact, so
the per-note gate accepts it.

## Steps

1. Create `tests/m043-acceptance/live-deploy/fixtures/` if absent.

2. Write `tests/m043-acceptance/live-deploy/evidence-template.md`. Frontmatter
   (YAML) + a body of capture sections. Use this exact frontmatter shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: live-deploy-evidence
   report_date: "YYYY-MM-DD"
   # --- SC-9 triad (set all three to "yes" for a completed live pass) ---
   redirect_verified: "no"      # 302 -> *.cloudflareaccess.com on the live URL
   ci_green: "no"               # wiki-cloudflare.yml workflow run went green
   giscus_working: "no"         # a giscus comment posted and persisted
   # --- P00 forward-pointed API confirmations (informational) ---
   edit_scope_grants_read: "unconfirmed"   # #Q-5: GET access/apps with Edit-only token -> 200?
   error_envelopes_match: "unconfirmed"    # #Q-6: 400/12130 vs 403/9109 confirmed?
   # --- deferred path (set both to close at shippable scope without a live run) ---
   deferred_validation: "no"    # "yes" forward-points the live pass
   signed_by: ""                # maintainer handle (required when deferred_validation: yes)
   ---
   ```

   Body sections (markdown):
   - `# M043 Live-Deploy Evidence Note`
   - an HTML comment instructing how to fill it (mirror the M033
     `report-template.md` comment), naming the two valid closing paths and the
     `validate-evidence.sh` command.
   - `## Environment` — Cloudflare account / project name / test repo / token
     scopes used.
   - `## Capture 1 — 302 redirect gate` — paste the `curl -sI` status line +
     `location:` header.
   - `## Capture 2 — green CI run` — the workflow-run URL.
   - `## Capture 3 — giscus comment` — confirmation + link.
   - `## Capture 4 — #Q-5 Edit-scope-grants-read` — the
     `GET /accounts/{id}/access/apps` result (200 + list, or 403 + fallback note).
   - `## Capture 5 — #Q-6 error envelopes` — the observed Zero-Trust-off and
     missing-scope HTTP status + error code.
   - `## Deferred-Validation Acknowledgment (if applicable)` — a block the
     maintainer fills when forward-pointing: the reason the live pass is deferred,
     the forward-pointer to this protocol, and the signer.
   - `## Maintainer Sign-Off` — recorded by / date.

   The template MUST literally contain the strings `deferred_validation` and
   `redirect_verified`.

3. Write `tests/m043-acceptance/live-deploy/validate-evidence.sh` with this exact
   content:

   ```bash
   #!/usr/bin/env bash
   # tests/m043-acceptance/live-deploy/validate-evidence.sh
   #
   # M043 SC-9 mechanical gate. Reads a filled live-deploy evidence note and
   # exits 0 iff EITHER:
   #   (a) completed live pass:
   #         redirect_verified: yes  AND  ci_green: yes  AND  giscus_working: yes
   #   (b) signed deferred-validation acknowledgment:
   #         deferred_validation: yes  AND  signed_by: <non-empty>
   #
   # A missing note prints the literal "live-deploy validation not run --
   # milestone close blocked" and exits 1 (fail-closed; mirrors M033
   # validate-report.sh / spec FR-13 SC-9).
   #
   # Bash 3.2 compatible. Frontmatter parsed with awk -- no jq, no python.
   # References: M043 spec FR-13 / US-4 / SC-9. MEM001 (bash 3.2).
   set -e -u -o pipefail

   NOTE="${1:-}"

   if [ -z "$NOTE" ]; then
     echo "usage: validate-evidence.sh <evidence-note.md>" >&2
     exit 2
   fi

   if [ ! -f "$NOTE" ]; then
     echo "live-deploy validation not run -- milestone close blocked" >&2
     echo "  expected evidence note at: $NOTE" >&2
     exit 1
   fi

   # Read one frontmatter scalar (between the first two `---` lines), strip
   # surrounding quotes/space, lower-case nothing (caller compares literals).
   fm_val() {
     awk -v key="$1" '
       BEGIN { n=0 }
       /^---[[:space:]]*$/ { n++; if (n==2) exit; next }
       n==1 {
         pat = "^" key ":[[:space:]]*"
         if ($0 ~ pat) {
           sub(pat, "", $0)
           sub(/[[:space:]]*#.*$/, "", $0)   # drop trailing inline comment
           gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
           gsub(/^"|"$/, "", $0)
           print
           exit
         }
       }
     ' "$NOTE"
   }

   redirect=$(fm_val redirect_verified)
   ci=$(fm_val ci_green)
   giscus=$(fm_val giscus_working)
   deferred=$(fm_val deferred_validation)
   signed=$(fm_val signed_by)

   # Path (b): signed deferred-validation note.
   if [ "$deferred" = "yes" ] && [ -n "$signed" ]; then
     echo "PASS: deferred-validation note signed_by=$signed (SC-9 forward-pointed)"
     exit 0
   fi

   # Path (a): completed live pass.
   if [ "$redirect" = "yes" ] && [ "$ci" = "yes" ] && [ "$giscus" = "yes" ]; then
     echo "PASS: live deploy verified (redirect+ci+giscus all yes)"
     exit 0
   fi

   echo "FAIL: evidence note satisfies neither SC-9 path" >&2
   echo "  completed-pass requires: redirect_verified=yes ci_green=yes giscus_working=yes" >&2
   echo "    got: redirect_verified=$redirect ci_green=$ci giscus_working=$giscus" >&2
   echo "  deferred path requires: deferred_validation=yes signed_by=<non-empty>" >&2
   echo "    got: deferred_validation=$deferred signed_by=$signed" >&2
   exit 1
   ```

   Make it executable (`chmod +x`).

4. Write `tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md` — a
   completed-pass example: frontmatter with `redirect_verified: "yes"`,
   `ci_green: "yes"`, `giscus_working: "yes"`, `edit_scope_grants_read: "yes"`,
   `error_envelopes_match: "yes"`, `deferred_validation: "no"`, plus a minimal
   body. MUST contain the string `redirect_verified`. (≥15 lines.)

5. Write `tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md` — a
   signed-deferred example: frontmatter with the triad all `"no"`,
   `deferred_validation: "yes"`, `signed_by: "maintainer-handle"`, plus a minimal
   Deferred-Validation Acknowledgment body. MUST contain the string
   `deferred_validation`. (≥15 lines.)

## Must-Haves

- `tests/m043-acceptance/live-deploy/evidence-template.md` (min 30 lines,
  contains "deferred_validation")
- `tests/m043-acceptance/live-deploy/validate-evidence.sh` (min 40 lines,
  contains "milestone close blocked")
- `tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md` (min 15 lines,
  contains "redirect_verified")
- `tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md` (min 15
  lines, contains "deferred_validation")

## Verification

```bash
test -f tests/m043-acceptance/live-deploy/evidence-template.md
test -x tests/m043-acceptance/live-deploy/validate-evidence.sh
bash tests/m043-acceptance/live-deploy/validate-evidence.sh tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md
bash tests/m043-acceptance/live-deploy/validate-evidence.sh tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md
```

## Inputs

### From Previous Tasks

None — T02 is independent of T01 inside P04.

### From Disk (Pre-existing)

- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` — the
  Bash-3.2 / awk-frontmatter / no-jq gate idiom to follow (note its
  fail-closed `exit 1` on a missing report and the `friction_blockers`/
  `eligible_testers` two-condition shape; M043's gate uses the same shape with
  the SC-9 triad-or-deferred conditions).
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` — the
  frontmatter-scalars + capture-sections template idiom.

## Constraints

- **Bash 3.2 / POSIX-sh** (MEM001): no `declare -A`, no process substitution, no
  jq, no python in `validate-evidence.sh`. awk/grep/sed only.
- **Fail-closed on missing note**: a non-existent note path MUST exit 1 with the
  literal `live-deploy validation not run -- milestone close blocked` (the T03
  deferred-note + missing-note verifiers depend on this string and exit code).
- The validator must trust the frontmatter scalars only (between the first two
  `---` lines) so body prose containing the same keys cannot spoof the verdict —
  the `fm_val` `n==2 exit` guard provides this.

## Expected Output

Four files on disk: `evidence-template.md`, an executable `validate-evidence.sh`,
and the two fixtures. The pass fixture and the deferred fixture each exit the
validator 0; a missing note exits 1.

## Notes

All four `## Verification` lines are self-contained within T02 (the validator and
both fixtures are T02 deliverables, satisfying Plan-Time Discipline rule 2's
co-authored clause). The fail-closed missing-note branch (`exit 1` on a
non-existent path) is asserted later by T03's `m043-p04-evidence-gate.sh`, which
drives this same validator against the pass fixture, the deferred fixture, AND a
guaranteed-absent path — keeping the cross-branch assertion out of T02's own
verification where the absent-path command would false-FAIL under
`auto-loop --step=V`.

Expected validator output on the pass fixture:
`PASS: live deploy verified (redirect+ci+giscus all yes)`. On the deferred fixture:
`PASS: deferred-validation note signed_by=maintainer-handle (SC-9 forward-pointed)`.

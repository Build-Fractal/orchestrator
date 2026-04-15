---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M005"
goal: "Knowledge entries include a content_hash: sha256:... field in frontmatter; rebuild-index.sh uses hashes to detect actual changes; dispatch results recorded as outcome: unchanged when agent output hash matches prior dispatch."
demo_sentence: "A developer runs bash scripts/knowledge/create-entry.sh with --body content and the resulting detail file includes a content_hash: sha256:{64-hex} field in frontmatter; running bash scripts/knowledge/rebuild-index.sh --root . reports changed vs unchanged counts by comparing stored hashes to recomputed body hashes; recording a dispatch result with bash scripts/lifecycle/record-result.sh accepts --outcome=unchanged without error."
risk: "medium"
depends_on: []
---

<!--
  P01 -- Content-Hash Idempotency
  ================================

  Context: closes the gap between "rebuild means re-read everything" and
  "rebuild detects actual changes." The stagnation signal (outcome: unchanged)
  lets the orchestrator know when dispatched agents produce identical output,
  enabling cost avoidance and stuck-loop detection upstream.

  Architectural decision:
    AD-1  Content hashes use sha256:{64-hex} format (matching index-pipeline
          convention). Never bare hex. Hash computed from body content only
          (excludes frontmatter).

  Cross-milestone dependencies:
    - M002 delivered the knowledge scripts (create-entry.sh, update-entry.sh,
      rebuild-index.sh) and index-utils.sh.
    - M004 P02 delivered scripts/lib/errors.sh (emit_result).
    Both are committed on main.
-->

## Must-Haves

### Truths

- Hash utility library exists with double-sourcing guard matching errors.sh pattern.
  - Check: `bash scripts/verify/p01-hash-lib.sh`
- Hash utility computes SHA-256 and formats as sha256:{hex} (never bare hex).
  - Check: `bash scripts/verify/p01-hash-format.sh`
- create-entry.sh writes content_hash field in frontmatter when creating entries.
  - Check: `bash scripts/verify/p01-create-hash.sh`
- update-entry.sh recomputes content_hash when body content changes via --body flag.
  - Check: `bash scripts/verify/p01-update-hash.sh`
- rebuild-index.sh detects changed vs unchanged entries via hash comparison.
  - Check: `bash scripts/verify/p01-rebuild-detects.sh`
- rebuild-index.sh reports changed and unchanged counts in its output.
  - Check: `bash scripts/verify/p01-rebuild-counts.sh`
- record-result.sh accepts unchanged as a valid outcome value.
  - Check: `bash scripts/verify/p01-outcome-unchanged.sh`

### Artifacts

- scripts/lib/hash.sh (min 20 lines, contains "compute_content_hash")
- scripts/knowledge/create-entry.sh (min 130 lines, contains "content_hash")
- scripts/knowledge/update-entry.sh (min 140 lines, contains "content_hash")
- scripts/knowledge/rebuild-index.sh (min 100 lines, contains "content_hash")
- scripts/lifecycle/record-result.sh (min 180 lines, contains "unchanged")
- scripts/verify/p01-hash-lib.sh (min 10 lines, contains "hash.sh")
- scripts/verify/p01-hash-format.sh (min 10 lines, contains "sha256:")
- scripts/verify/p01-create-hash.sh (min 10 lines, contains "content_hash")
- scripts/verify/p01-update-hash.sh (min 10 lines, contains "content_hash")
- scripts/verify/p01-rebuild-detects.sh (min 10 lines, contains "content_hash")
- scripts/verify/p01-rebuild-counts.sh (min 10 lines, contains "unchanged")
- scripts/verify/p01-outcome-unchanged.sh (min 10 lines, contains "unchanged")

### Key Links

- scripts/lib/hash.sh -> scripts/knowledge/create-entry.sh
- scripts/lib/hash.sh -> scripts/knowledge/update-entry.sh
- scripts/lib/hash.sh -> scripts/knowledge/rebuild-index.sh
- scripts/knowledge/create-entry.sh -> scripts/knowledge/lib/index-utils.sh
- scripts/knowledge/update-entry.sh -> scripts/knowledge/lib/index-utils.sh
- scripts/knowledge/rebuild-index.sh -> scripts/knowledge/lib/index-utils.sh
- scripts/lifecycle/record-result.sh -> (standalone, outcome enum extended)

## Tasks

### T01: Hash utility library + verification scripts

Creates `scripts/lib/hash.sh` with the `compute_content_hash` function (SHA-256
of body content, formatted as `sha256:{hex}`), a double-sourcing guard following
the `scripts/lib/errors.sh` pattern, and a `compute_file_body_hash` helper that
extracts the body (content after the second `---` frontmatter delimiter) from a
markdown file and hashes it. Also creates all seven verification scripts for
this phase under `scripts/verify/p01-*.sh`. Zero upstream dependencies.

Full plan: `tasks/T01-PLAN.md`

### T02: Integrate hash into create-entry.sh

Updates `scripts/knowledge/create-entry.sh` to source `scripts/lib/hash.sh`,
compute the content hash from the `--body` argument, and write `content_hash:
sha256:{hex}` into the YAML frontmatter of the new detail file. Depends on T01
(hash.sh must exist).

Full plan: `tasks/T02-PLAN.md`

### T03: Add body update and hash recomputation to update-entry.sh

Updates `scripts/knowledge/update-entry.sh` to accept a `--body` flag for
replacing body content. When body changes, recomputes `content_hash` using
`compute_content_hash` from hash.sh. Also recomputes hash on explicit
`--recompute-hash` flag (for cases where body was modified by other means).
Depends on T01 (hash.sh).

Full plan: `tasks/T03-PLAN.md`

### T04: Hash-aware rebuild in rebuild-index.sh

Updates `scripts/knowledge/rebuild-index.sh` to compare each file's stored
`content_hash` frontmatter value against a freshly computed hash of its body.
Reports counts of changed, unchanged, and missing-hash entries in its output.
Depends on T01 (hash.sh).

Full plan: `tasks/T04-PLAN.md`

### T05: Add unchanged outcome to record-result.sh

Updates `scripts/lifecycle/record-result.sh` to accept `unchanged` as a valid
outcome value in the outcome validation case statement. Standalone change with
no dependency on other P01 tasks (the hash library is not needed here -- the
caller determines whether the outcome is unchanged before invoking the script).

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (hash utility + verify scripts)
  |
  +---> T02 (create-entry.sh integration)
  |
  +---> T03 (update-entry.sh integration)
  |
  +---> T04 (rebuild-index.sh hash-aware rebuild)

T05 (record-result.sh unchanged outcome)   [independent of T01-T04]
```

T01 is the critical-path gate -- T02, T03, T04 all consume the hash library.
T02, T03, T04 are independent of each other and can execute in parallel.
T05 is fully independent and can execute at any time, including in parallel
with T01.

## Files Likely Touched

- scripts/lib/hash.sh (create)
- scripts/knowledge/create-entry.sh (modify)
- scripts/knowledge/update-entry.sh (modify)
- scripts/knowledge/rebuild-index.sh (modify)
- scripts/lifecycle/record-result.sh (modify)
- scripts/verify/p01-hash-lib.sh (create)
- scripts/verify/p01-hash-format.sh (create)
- scripts/verify/p01-create-hash.sh (create)
- scripts/verify/p01-update-hash.sh (create)
- scripts/verify/p01-rebuild-detects.sh (create)
- scripts/verify/p01-rebuild-counts.sh (create)
- scripts/verify/p01-outcome-unchanged.sh (create)

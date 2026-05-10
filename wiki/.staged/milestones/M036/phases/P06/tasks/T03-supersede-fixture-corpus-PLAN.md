---
schema_version: "1.0"
type: task-plan
id: "T03"
parent: "P06"
milestone: "M036"
parallelizable: false
---

# T03 — On-disk supersede-corpus fixtures + extract-manifest fixture

## Goal

Author the on-disk fixture set under `tests/fixtures/m036-p06-supersede-corpus/` and the single-document extract manifest at `tests/fixtures/m036-p06-extract-manifest.yaml`. The fixtures are the inputs to the SC-6 acceptance harness in T04 (`tests/test-reference-supersede-chain.sh`). Author two T03 token-presence verifiers that gate the fixture shape.

## Context (zero-context summary)

The SC-6 harness in T04 needs three on-disk fixtures to drive a complete supersede-chain story:

1. **Original V1 reference chunk** at `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` — full FR-2 frontmatter (source, published, version, cite_id, topic_tags, applies_to_field) plus a body containing the literal string `BODY V1` so the body sha256 differs from the mutated V2 fixture. The chunk_id `REF-cms-rule-supersede-fixture` matches the M036/P04 chunk-id convention.

2. **Mutated V2 reference chunk** at `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` — same path basename (the harness copies one OR the other into the workspace's reference root depending on whether it's testing the V1 first-extraction or the V2 mutation re-extraction), same FR-2 frontmatter, body containing `BODY V2`.

3. **Citer spec chunk** at `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` — declares `cites: [REF-cms-rule-supersede-fixture]` (the V1 chunk_id, NOT the v2 successor). The harness stages this into the workspace's `knowledge/spec/<scope>/` so the typed-edge traverser will find a citer of the V1 chunk, exercising the SC-6 REVIEW: line emission.

The fixtures are deliberately separate from the M036/P04 reference-corpus fixture (`tests/fixtures/m036-p04-reference-corpus/`) so the supersede story is isolated from the P04 ingest happy-path and the P05 graph-traversal happy-path. Co-locating supersede-specific fixtures under their own M036/P06 directory follows the M036-canonical fixture-naming convention.

The single-document extract manifest at `tests/fixtures/m036-p06-extract-manifest.yaml` is a reference-shape only fixture (the SC-6/SC-13 harnesses inline their own manifests via heredocs into `mktemp -d` workspaces). The on-disk manifest exists primarily as documentation + a stable shape gate; the verifier asserts it has the expected fields.

The fixtures are small (~5 KB total), markdown / YAML only; no host-tool dependency.

## Inputs

API surface T03 consumes (from upstream):

- M036/P04 fixture-corpus shape (`tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md`) — used as a reference template for the FR-2 provenance frontmatter shape. T03's fixtures match the same field set: schema_version, type, milestone, category, chunk_id, cite_id, source, published, version, tier, content_hash, size_bytes, summary_mode, topic_tags, applies_to_field, scope_tags.
- M036/P02 manifest contract (`references/extract-manifest-contract.md`) — used as a template for the single-document manifest shape. T03's manifest matches the field set: schema_version, type, milestone, size_cap_bytes, documents (with cite_id, source_path, category, source, published, version, topic_tags, applies_to_field, tier, summary_mode, summary).
- M036/P04 spec-chunk citer convention — spec chunks under `knowledge/spec/<scope>/` declare `cites: [REF-...]` in their frontmatter; the typed-edge traverser walks these.

## Files Touched

- `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md` (create)
- `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md` (create)
- `tests/fixtures/m036-p06-extract-manifest.yaml` (create)
- `tools/verify/m036-p06-fixture-corpus-shape.sh` (create)
- `tools/verify/m036-p06-extract-manifest-shape.sh` (create)

## Steps

1. **Create the original V1 reference chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-chunk
   milestone: "M036"
   category: "cms-rule"
   id: "REF-cms-rule-supersede-fixture"
   chunk_id: "REF-cms-rule-supersede-fixture"
   cite_id: "supersede-fixture"
   source: "internal-test"
   published: "2026-05-02"
   version: 1
   tier: 1
   content_hash: "0000000000000000000000000000000000000000000000000000000000000001"
   size_bytes: 64
   summary_mode: "operator"
   topic_tags: [pbj-staffing]
   applies_to_field: [staff_count]
   scope_tags: "[project], [milestone:M036]"
   ---

   BODY V1 -- M036/P06 supersede-chain fixture; original version. Body content
   is intentionally distinct from the mutated/ sibling so the content_hash gate
   in extract-reference.sh fires on re-extraction.
   ```

2. **Create the mutated V2 reference chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/mutated/cms-rule/REF-cms-rule-supersede-fixture.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-chunk
   milestone: "M036"
   category: "cms-rule"
   id: "REF-cms-rule-supersede-fixture"
   chunk_id: "REF-cms-rule-supersede-fixture"
   cite_id: "supersede-fixture"
   source: "internal-test"
   published: "2026-05-02"
   version: 2
   tier: 1
   content_hash: "0000000000000000000000000000000000000000000000000000000000000002"
   size_bytes: 64
   summary_mode: "operator"
   topic_tags: [pbj-staffing]
   applies_to_field: [staff_count]
   scope_tags: "[project], [milestone:M036]"
   ---

   BODY V2 -- M036/P06 supersede-chain fixture; mutated successor. The harness
   replaces the original/ source with this content between extract runs to
   exercise the supersede authoring branch.
   ```

   Note: the `content_hash` and `size_bytes` values in BOTH fixtures are placeholders. The harness in T04 does NOT assert these against the body; the harness invokes the live extract driver which computes its own hashes from the live source. These fixtures' frontmatter values are documentation-shape only.

3. **Create the citer spec chunk fixture** at `tests/fixtures/m036-p06-supersede-corpus/citer-spec/SPEC-requirement-supersede-citer.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: spec-chunk
   milestone: "M-fixture"
   category: "requirement"
   id: "SPEC-requirement-supersede-citer"
   chunk_id: "SPEC-requirement-supersede-citer"
   spec_id: "FR-supersede-citer"
   cites: [REF-cms-rule-supersede-fixture]
   topic_tags: [pbj-staffing]
   scope_tags: "[project]"
   ---

   # FR-supersede-citer

   This synthetic spec requirement cites the M036/P06 supersede-fixture
   reference chunk in its V1 form. After the fixture's V2 successor is
   authored, the M036/P06 cross-citer REVIEW: walk should surface this
   chunk_id with reason=cites-superseded.
   ```

4. **Create the single-document extract manifest** at `tests/fixtures/m036-p06-extract-manifest.yaml`. Verbatim:

   ```yaml
   # tests/fixtures/m036-p06-extract-manifest.yaml -- M036 P06 T03.
   #
   # Reference-shape extract manifest for the supersede-fixture document.
   # Used as documentation + a stable shape gate; the SC-6/SC-13 harnesses
   # inline their own manifests into mktemp -d workspaces because the
   # source path here points outside the workspace root.
   schema_version: "1.0"
   type: extract-manifest
   milestone: "M036"
   size_cap_bytes: 10485760

   documents:
     - cite_id: "supersede-fixture"
       source_path: "../m036-p06-supersede-corpus/original/cms-rule/REF-cms-rule-supersede-fixture.md"
       category: "cms-rule"
       source: "internal-test"
       published: "2026-05-02"
       version: "1"
       topic_tags: [pbj-staffing]
       applies_to_field: [staff_count]
       tier: 1
       summary_mode: "operator"
       summary: "M036 P06 supersede-fixture; the V1 source for the supersede-chain harness."
   ```

5. **Author `tools/verify/m036-p06-fixture-corpus-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-fixture-corpus-shape.sh -- M036 P06 T03.
   # Token-presence verifier on the supersede-corpus fixtures.
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   BASE="$ROOT/tests/fixtures/m036-p06-supersede-corpus"
   V1="$BASE/original/cms-rule/REF-cms-rule-supersede-fixture.md"
   V2="$BASE/mutated/cms-rule/REF-cms-rule-supersede-fixture.md"
   CITER="$BASE/citer-spec/SPEC-requirement-supersede-citer.md"
   pass=0
   fail=0
   chk() {
     local label="$1" file="$2" pat="$3"
     if [ -f "$file" ] && grep -qF -e "$pat" "$file"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (file=$file pat=$pat)"
       fail=$((fail + 1))
     fi
   }
   chk "v1-exists"                    "$V1" "BODY V1"
   chk "v1-cite_id"                   "$V1" 'cite_id: "supersede-fixture"'
   chk "v1-category-cms-rule"         "$V1" 'category: "cms-rule"'
   chk "v1-topic-tag-pbj-staffing"    "$V1" "pbj-staffing"
   chk "v1-applies-to-field"          "$V1" "staff_count"
   chk "v2-exists"                    "$V2" "BODY V2"
   chk "v2-cite_id"                   "$V2" 'cite_id: "supersede-fixture"'
   chk "v2-version-2"                 "$V2" "version: 2"
   chk "citer-spec-exists"            "$CITER" "SPEC-requirement-supersede-citer"
   chk "citer-cites-v1-id"            "$CITER" "cites: [REF-cms-rule-supersede-fixture]"
   # Negative: citer must NOT name the v2 successor (the test exercises
   # the chain-walk from V1 -- if the citer pointed at v2 directly, the
   # supersede-walk would have nothing to surface).
   if [ -f "$CITER" ] && grep -qF -e "REF-cms-rule-supersede-fixture-v2" "$CITER"; then
     echo "FAIL: citer-must-not-name-v2-successor"
     fail=$((fail + 1))
   else
     echo "PASS: citer-points-at-V1-only"
     pass=$((pass + 1))
   fi
   echo "SUMMARY: m036-p06-fixture-corpus-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/m036-p06-extract-manifest-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-extract-manifest-shape.sh -- M036 P06 T03.
   # Token-presence verifier on the supersede-fixture extract manifest.
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/tests/fixtures/m036-p06-extract-manifest.yaml"
   pass=0
   fail=0
   chk() {
     local label="$1" pat="$2"
     if grep -qF -e "$pat" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing: $pat)"
       fail=$((fail + 1))
     fi
   }
   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=0 fail=1"
     exit 1
   fi
   chk "schema_version-declared"      "schema_version:"
   chk "type-extract-manifest"        "type: extract-manifest"
   chk "milestone-M036"               'milestone: "M036"'
   chk "size_cap_bytes-declared"      "size_cap_bytes:"
   chk "documents-array"              "documents:"
   chk "fixture-cite_id"              'cite_id: "supersede-fixture"'
   chk "category-cms-rule"            'category: "cms-rule"'
   chk "tier-1"                       "tier: 1"
   chk "summary_mode-operator"        'summary_mode: "operator"'
   echo "SUMMARY: m036-p06-extract-manifest-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

7. Make both new verifier scripts executable (`chmod +x`).

## Must-Haves (subset T03 addresses)

- The supersede-corpus fixtures and the manifest fixture exist on disk with the expected shape (V1 + mutated + citer-spec).
- The `tests/fixtures/m036-p06-extract-manifest.yaml` fixture exists with the expected single-document manifest shape.

## Verification

```bash
bash tools/verify/m036-p06-fixture-corpus-shape.sh
bash tools/verify/m036-p06-extract-manifest-shape.sh
```

## Notes

The V1 and V2 fixtures share the same path basename intentionally — the SC-6 harness in T04 uses one OR the other depending on the run iteration. The `original/` vs `mutated/` directory split makes that copy operation unambiguous (`cp tests/fixtures/m036-p06-supersede-corpus/original/...` for the first run; `cp tests/fixtures/m036-p06-supersede-corpus/mutated/...` for the second).

The placeholder `content_hash` values are NOT computed from the body — the live extract driver computes the real hash from the source binary at extract time. Token-shape verifiers do not enforce content_hash equality. This is consistent with the M036/P04 fixture-corpus convention where placeholder hashes are present in the frontmatter but the harness does not assert them against the body.

The citer-spec chunk lives under `citer-spec/` (NOT `cms-rule/`) so it is NOT picked up by the M036/P04 ingest driver's taxonomy walker (which only descends into the four canonical category directories). The harness in T04 explicitly stages it into the workspace's `knowledge/spec/<scope>/` path, where the typed-edge traverser's spec-chunk source-glob will find it.

Expected verifier outputs: fixture-corpus-shape reports `pass=11 fail=0`; extract-manifest-shape reports `pass=9 fail=0`.

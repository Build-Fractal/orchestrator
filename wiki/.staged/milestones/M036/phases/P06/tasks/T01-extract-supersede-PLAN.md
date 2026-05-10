---
schema_version: "1.0"
type: task-plan
id: "T01"
parent: "P06"
milestone: "M036"
parallelizable: false
---

# T01 — Extract-side supersede authoring + helper lib + end-to-end behavioral

## Goal

Wire the supersede-chain authoring branch into `scripts/knowledge/extract-reference.sh` so a re-extraction of a content-mutated source produces a versioned successor file (`REF-<cat>-<id>-v<N+1>.md`), amends the prior chain-tip with `superseded_by:` frontmatter, and emits a `SUPERSEDED:` stdout line. Author the supporting pure-lib helper at `scripts/knowledge/lib/extract-supersede.sh`. Author three verifiers (two shape, one end-to-end behavioral) covering the contract.

## Context (zero-context summary)

`scripts/knowledge/extract-reference.sh` is the M036/P02 driver for `orchestrator:extract`. It iterates a manifest's documents, computes each source binary's sha256, preserves the binary under `_originals/`, dispatches Tier 1 extraction via the format-adapter registry, and writes a Tier 0 chunk file at `<reference-root>/<category>/REF-<category>-<cite_id>.md` with FR-2 provenance frontmatter + a body that is the operator/stub/auto summary.

Today the driver has two paths on the chunk-existence check at lines ~115-122:

```bash
if [ -f "$chunk_file" ]; then
  prior=$(grep -E '^content_hash:' "$chunk_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
  if [ "$prior" = "$hash" ]; then
    echo "SKIPPED: $cite_id reason=unchanged"
    i=$((i + 1))
    continue
  fi
fi
```

Path A (chunk file does not exist): falls through to the standard write-chunk path → emits `EXTRACTED:`.
Path B (chunk file exists AND `content_hash:` matches new hash): SKIPPED early-return.
Path C (chunk file exists AND `content_hash:` differs): falls through to write-chunk → silently overwrites the prior chunk (this is the gap T01 fixes — the prior version is lost, no chain is authored).

T01 inserts a NEW branch in the gap of Path C: when the chunk file exists AND the hashes differ, walk the existing chain to find the chain tip, write a NEW chunk at `REF-<cat>-<id>-v<N+1>.md` (preserving the prior version), amend the prior tip's frontmatter with `superseded_by: REF-<cat>-<id>-v<N+1>`, emit `SUPERSEDED: <prior-id> -> <new-id>`. Path A and Path B remain byte-equivalent.

The chain-walking convention: the first chunk written for a `<cite_id>` lives at `REF-<cat>-<id>.md` (no version suffix); the second-and-later live at `REF-<cat>-<id>-v2.md`, `REF-<cat>-<id>-v3.md`, etc. The chain tip is the highest-numbered file present (or the bare-suffix file if no `-v*` files exist yet). The next version slot is `chain-tip-version + 1` where the bare-suffix file counts as version 1.

The `supersedes:` frontmatter on a new chunk names the immediate predecessor; the `superseded_by:` frontmatter on the predecessor names the successor. The chain is therefore double-linked. The `version:` frontmatter scalar on each chunk records the integer version slot (1, 2, 3, ...).

The amend operation MUST be idempotent — if the prior chunk already has `superseded_by:` matching the new id, do not duplicate the line. (Defends against re-running T01's branch on the same mutation pair.)

## Inputs

API surface T01 consumes (from upstream):

- P02 `scripts/knowledge/extract-reference.sh` (~239 lines today): main driver. T01 sources the new helper at the top (alongside the existing `lib/extract-manifest.sh`, `lib/extract-binary-preservation.sh`, `lib/extract-tier-0-summary.sh`, `lib/extract-tier-2-llm.sh`, `lib/extract-tier-2-gate.sh` source lines at lines 28-36) and inserts the supersede branch at the chunk-file-exists gate (lines ~115-123).
- P02 `scripts/knowledge/lib/extract-binary-preservation.sh::preservation_sha256(path) -> stdout: 64-char hex` — already used by the driver to compute `$hash`. T01 re-uses unchanged.
- P02 manifest contract (`references/extract-manifest-contract.md`): each document declares `cite_id`, `category`, `source_path`, `tier`, `summary_mode`, optional `version:` (the operator-facing handle we now author into the chunk frontmatter on each successor write). T01's helper does NOT read the manifest — it operates on the chunk filesystem layout only.

## Files Touched

- `scripts/knowledge/lib/extract-supersede.sh` (create — pure-lib MEM004 helper)
- `scripts/knowledge/extract-reference.sh` (modify — source helper + add supersede branch in chunk-file-exists gate + emit SUPERSEDED: stdout)
- `tools/verify/m036-p06-extract-supersede-shape.sh` (create — token-presence on the driver)
- `tools/verify/m036-p06-extract-supersede-helper-shape.sh` (create — token-presence on the helper)
- `tools/verify/m036-p06-supersede-chain-end-to-end.sh` (create — behavioral)

## Steps

1. **Author `scripts/knowledge/lib/extract-supersede.sh`**. Pure-lib MEM004; no top-level execution. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # scripts/knowledge/lib/extract-supersede.sh -- M036 P06 T01.
   #
   # Pure-lib MEM004 helper for the supersede-chain authoring branch in
   # scripts/knowledge/extract-reference.sh. No top-level execution.
   # Functions take args, emit to stdout / exit code only.
   #
   # Bash 3.2 / POSIX-sh per CON-2.
   #
   # Functions:
   #   supersede_find_chain_tip <chunk-dir> <category> <cite_id>
   #     -> stdout: absolute path to the current chain-tip chunk file.
   #        Walks REF-<cat>-<id>.md, REF-<cat>-<id>-v2.md, ...
   #        Returns the highest-numbered file present.
   #        If the bare-suffix file does not exist, exit 1.
   #
   #   supersede_next_version <chunk-dir> <category> <cite_id>
   #     -> stdout: integer N+1 (the next free version slot).
   #        Bare-suffix file counts as version 1.
   #        If no chunk file exists yet, returns 1 (first-time extraction
   #        path; caller should not be invoking this in that case).
   #
   #   supersede_amend_prior_chunk <prior-chunk-file> <new-chunk-id>
   #     -> mutates the prior chunk frontmatter in-place to add
   #        `superseded_by: <new-chunk-id>` after the existing
   #        `content_hash:` line. Idempotent: if the prior chunk already
   #        contains `superseded_by: <new-chunk-id>`, no-op.
   #
   set -eu

   supersede_find_chain_tip() {
     local chunk_dir="$1"
     local category="$2"
     local cite_id="$3"
     local bare="$chunk_dir/REF-${category}-${cite_id}.md"
     if [ ! -f "$bare" ]; then
       return 1
     fi
     # Find highest -vN.md (N>=2). Bare-suffix is version 1.
     local highest=1
     local highest_file="$bare"
     local f n
     for f in "$chunk_dir"/REF-"${category}"-"${cite_id}"-v*.md; do
       [ -f "$f" ] || continue
       n=$(printf '%s\n' "$f" | sed -E "s|.*-v([0-9]+)\.md\$|\1|")
       case "$n" in
         ''|*[!0-9]*) continue ;;
       esac
       if [ "$n" -gt "$highest" ]; then
         highest="$n"
         highest_file="$f"
       fi
     done
     printf '%s\n' "$highest_file"
   }

   supersede_next_version() {
     local chunk_dir="$1"
     local category="$2"
     local cite_id="$3"
     local bare="$chunk_dir/REF-${category}-${cite_id}.md"
     if [ ! -f "$bare" ]; then
       printf '1\n'
       return 0
     fi
     local highest=1
     local f n
     for f in "$chunk_dir"/REF-"${category}"-"${cite_id}"-v*.md; do
       [ -f "$f" ] || continue
       n=$(printf '%s\n' "$f" | sed -E "s|.*-v([0-9]+)\.md\$|\1|")
       case "$n" in
         ''|*[!0-9]*) continue ;;
       esac
       if [ "$n" -gt "$highest" ]; then
         highest="$n"
       fi
     done
     printf '%s\n' "$((highest + 1))"
   }

   supersede_amend_prior_chunk() {
     local prior_file="$1"
     local new_chunk_id="$2"
     # Idempotency: if the line is already present, no-op.
     if grep -qF -e "superseded_by: \"${new_chunk_id}\"" "$prior_file"; then
       return 0
     fi
     # Insert after the existing content_hash: line. Use a tmpfile +
     # rename to keep Bash 3.2 / BSD-sed compatibility.
     local tmp
     tmp=$(mktemp "${TMPDIR:-/tmp}/m036-p06-amend.XXXXXX")
     awk -v sb="superseded_by: \"${new_chunk_id}\"" '
       { print }
       /^content_hash:/ && !inserted { print sb; inserted=1 }
     ' "$prior_file" > "$tmp"
     mv "$tmp" "$prior_file"
   }
   ```

2. **Modify `scripts/knowledge/extract-reference.sh`**. Two edits:

   a. **Source the new helper**. After line 36 (`. "$HERE/lib/extract-tier-2-gate.sh"`), insert:

      ```bash
      # shellcheck disable=SC1091
      . "$HERE/lib/extract-supersede.sh"          # M036/P06 T01
      ```

   b. **Add the supersede branch on the content-hash mismatch path**. Locate the existing block at approximately lines 115-123:

      ```bash
        # Idempotency gate: if existing chunk has matching content_hash, SKIP.
        if [ -f "$chunk_file" ]; then
          prior=$(grep -E '^content_hash:' "$chunk_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
          if [ "$prior" = "$hash" ]; then
            echo "SKIPPED: $cite_id reason=unchanged"
            i=$((i + 1))
            continue
          fi
        fi
      ```

      Replace it with the following expanded form (keep the SKIPPED fast path byte-equivalent; add the supersede branch on the mismatch path):

      ```bash
        # Idempotency gate: if existing chunk has matching content_hash, SKIP.
        # Supersede branch (M036/P06 T01): if existing chunk has different
        # content_hash, write a versioned successor and amend the prior
        # chain-tip with superseded_by: rather than silently overwriting.
        prior_chunk_id_for_supersede=""
        new_version_slot=""
        if [ -f "$chunk_file" ]; then
          prior=$(grep -E '^content_hash:' "$chunk_file" | head -n 1 | sed -E 's/^content_hash:[[:space:]]*//' | tr -d '"')
          if [ "$prior" = "$hash" ]; then
            echo "SKIPPED: $cite_id reason=unchanged"
            i=$((i + 1))
            continue
          fi
          # Hashes differ: walk to the chain tip, compute next slot, retarget
          # the chunk_file path to the new versioned successor file, and stash
          # the prior chain-tip path for post-write amendment.
          tip_file=$(supersede_find_chain_tip "$chunk_dir" "$category" "$cite_id")
          new_version_slot=$(supersede_next_version "$chunk_dir" "$category" "$cite_id")
          prior_chunk_id_for_supersede=$(basename "$tip_file" .md)
          chunk_file="$chunk_dir/REF-${category}-${cite_id}-v${new_version_slot}.md"
        fi
      ```

   c. **Stamp `supersedes:` and `version:` into the new chunk frontmatter**. Locate the `printf 'version: "%s"\n' ...` line in the chunk-emit block (line ~212). Replace it with:

      ```bash
          if [ -n "${new_version_slot:-}" ]; then
            printf 'version: %s\n' "$new_version_slot"
            printf 'supersedes: "%s"\n' "$prior_chunk_id_for_supersede"
          else
            printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
          fi
      ```

      Rationale: the existing `version:` field is operator-asserted from the manifest on first-time extraction (Path A); on the supersede path it is the integer slot computed by the helper and the predecessor id is stamped as `supersedes:`. Both are present in chunk frontmatter for graph traversal.

   d. **Amend the prior chunk + emit `SUPERSEDED:` stdout** AFTER the chunk file is written but BEFORE the `EXTRACTED:` line. Locate the `if [ "$tier_2_verdict" = "BLOCK" ]; then ... else ... fi` emission block (line ~227-235). Insert the supersede amendment + emission BEFORE that block:

      ```bash
        # M036/P06 T01: if we just wrote a versioned successor, amend the
        # prior chain-tip's frontmatter with superseded_by: pointing at us.
        if [ -n "${new_version_slot:-}" ] && [ -n "${prior_chunk_id_for_supersede:-}" ]; then
          new_chunk_id="REF-${category}-${cite_id}-v${new_version_slot}"
          prior_tip_file="$chunk_dir/${prior_chunk_id_for_supersede}.md"
          supersede_amend_prior_chunk "$prior_tip_file" "$new_chunk_id"
          echo "SUPERSEDED: $prior_chunk_id_for_supersede -> $new_chunk_id"
        fi
      ```

      Note: keep the existing `EXTRACTED:` emission untouched. A successful supersede produces both a `SUPERSEDED:` line and an `EXTRACTED:` line for the new successor — the harness asserts both.

3. **Author `tools/verify/m036-p06-extract-supersede-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-extract-supersede-shape.sh -- M036 P06 T01.
   # Token-presence verifier on scripts/knowledge/extract-reference.sh
   # asserting the supersede branch tokens are present. AD-19 single-
   # script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/knowledge/extract-reference.sh"
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
     echo "SUMMARY: m036-p06-extract-supersede-shape.sh pass=0 fail=1"
     exit 1
   fi
   chk "sources-helper-lib"            "lib/extract-supersede.sh"
   chk "calls-find-chain-tip"          "supersede_find_chain_tip"
   chk "calls-next-version"            "supersede_next_version"
   chk "calls-amend-prior-chunk"       "supersede_amend_prior_chunk"
   chk "emits-SUPERSEDED-prefix"       "SUPERSEDED:"
   chk "stamps-supersedes-frontmatter" "supersedes:"
   chk "stamps-version-on-supersede"   "printf 'version: %s\\\\n'"
   chk "writes-versioned-successor"    'REF-${category}-${cite_id}-v'
   chk "preserves-skipped-fast-path"   "SKIPPED: \$cite_id reason=unchanged"
   chk "M036-P06-attribution-comment"  "M036/P06"
   echo "SUMMARY: m036-p06-extract-supersede-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

4. **Author `tools/verify/m036-p06-extract-supersede-helper-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-extract-supersede-helper-shape.sh -- M036 P06 T01.
   # Token-presence verifier on scripts/knowledge/lib/extract-supersede.sh.
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/knowledge/lib/extract-supersede.sh"
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
     echo "SUMMARY: m036-p06-extract-supersede-helper-shape.sh pass=0 fail=1"
     exit 1
   fi
   chk "find-chain-tip-defined"       "supersede_find_chain_tip()"
   chk "next-version-defined"         "supersede_next_version()"
   chk "amend-prior-chunk-defined"    "supersede_amend_prior_chunk()"
   chk "MEM004-attribution-comment"   "MEM004"
   chk "set-eu-strict"                "set -eu"
   chk "no-top-level-exec-marker"     "Pure-lib MEM004 helper"
   echo "SUMMARY: m036-p06-extract-supersede-helper-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/m036-p06-supersede-chain-end-to-end.sh`**. Behavioral verifier; markdown-only mktemp -d workspace; drives extract twice with a body mutation in between. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-supersede-chain-end-to-end.sh -- M036 P06 T01.
   # Behavioral verifier: stages a markdown-only manifest, runs the
   # extract driver, mutates the source body, runs again, asserts (a)
   # versioned successor REF-cms-rule-fixture-v2.md exists, (b) prior
   # chunk frontmatter contains superseded_by:, (c) stdout SUPERSEDED:
   # line emitted, (d) re-running on the mutated source emits SKIPPED.
   # No host-tool dependency (markdown floor only).
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-supersede.XXXXXX")"
   trap 'rm -rf "$WS"' EXIT
   DRV="$ROOT/scripts/knowledge/extract-reference.sh"
   pass=0
   fail=0

   # Stage source markdown (V1).
   {
     printf '%s\n' "# Supersede Fixture"
     printf '%s\n' ""
     printf '%s\n' "BODY V1 -- original content for the supersede-chain end-to-end verifier."
   } > "$WS/source.md"

   # Stage manifest pointing at the source.
   cat > "$WS/manifest.yaml" <<'YAML'
   schema_version: "1.0"
   type: extract-manifest
   milestone: "M036"
   size_cap_bytes: 10485760

   documents:
     - cite_id: "supersede-fixture"
       source_path: "source.md"
       category: "cms-rule"
       source: "internal-test"
       published: "2026-05-02"
       version: "1"
       topic_tags: []
       applies_to_field: []
       tier: 1
       summary_mode: "operator"
       summary: "Supersede fixture summary."
   YAML

   REF="$WS/ref"
   ORIG="$WS/orig"

   # First extract -- writes V1 chunk file.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF" --originals-root "$ORIG" \
     >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
       echo "FAIL: first extract failed (rc=$?)"
       cat "$WS/run1.stderr" >&2
       echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=0 fail=1"
       exit 1
     }

   V1_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture.md"
   if [ -f "$V1_FILE" ]; then
     echo "PASS: V1-chunk-written"
     pass=$((pass + 1))
   else
     echo "FAIL: V1-chunk-not-written"
     fail=$((fail + 1))
   fi

   # Mutate source body.
   {
     printf '%s\n' "# Supersede Fixture"
     printf '%s\n' ""
     printf '%s\n' "BODY V2 -- mutated content; content_hash now differs from V1."
   } > "$WS/source.md"

   # Second extract -- supersede branch should fire.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF" --originals-root "$ORIG" \
     >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
       echo "FAIL: second extract failed (rc=$?)"
       cat "$WS/run2.stderr" >&2
       echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=$pass fail=$((fail + 1))"
       exit 1
     }

   V2_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture-v2.md"
   if [ -f "$V2_FILE" ]; then
     echo "PASS: V2-chunk-written"
     pass=$((pass + 1))
   else
     echo "FAIL: V2-chunk-not-written"
     fail=$((fail + 1))
   fi

   if grep -qF -e 'superseded_by: "REF-cms-rule-supersede-fixture-v2"' "$V1_FILE"; then
     echo "PASS: V1-frontmatter-amended-with-superseded_by"
     pass=$((pass + 1))
   else
     echo "FAIL: V1-frontmatter-missing-superseded_by"
     fail=$((fail + 1))
   fi

   if grep -qF -e "SUPERSEDED: REF-cms-rule-supersede-fixture -> REF-cms-rule-supersede-fixture-v2" "$WS/run2.stdout"; then
     echo "PASS: SUPERSEDED-stdout-emitted"
     pass=$((pass + 1))
   else
     echo "FAIL: SUPERSEDED-stdout-missing"
     fail=$((fail + 1))
   fi

   # Third extract on now-mutated source -- chunk_file path is now the v2
   # successor; content_hash gate matches; emit SKIPPED.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF" --originals-root "$ORIG" \
     >"$WS/run3.stdout" 2>"$WS/run3.stderr" || {
       echo "FAIL: third extract failed (rc=$?)"
       cat "$WS/run3.stderr" >&2
       fail=$((fail + 1))
     }

   if grep -qF -e "SKIPPED: supersede-fixture reason=unchanged" "$WS/run3.stdout"; then
     echo "PASS: third-run-emits-SKIPPED"
     pass=$((pass + 1))
   else
     echo "FAIL: third-run-did-not-emit-SKIPPED"
     fail=$((fail + 1))
   fi

   echo "SUMMARY: m036-p06-supersede-chain-end-to-end.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. Make all three new verifier scripts and the helper lib executable (`chmod +x`).

## Must-Haves (subset T01 addresses)

- `scripts/knowledge/extract-reference.sh` declares the supersede authoring branch (writes versioned successor + `superseded_by:` lineage) and the `SUPERSEDED:` stdout protocol on content-hash mismatch.
- `scripts/knowledge/lib/extract-supersede.sh` defines `supersede_find_chain_tip()`, `supersede_next_version()`, and `supersede_amend_prior_chunk()` as a pure-lib MEM004 helper.
- A mutated source body re-extracted produces a `-v2.md` successor file, the prior chunk gains `superseded_by:`, and re-running on the now-mutated source emits SKIPPED.

## Verification

```bash
bash tools/verify/m036-p06-extract-supersede-shape.sh
bash tools/verify/m036-p06-extract-supersede-helper-shape.sh
bash tools/verify/m036-p06-supersede-chain-end-to-end.sh
```

## Notes

The most common implementation gotcha is **double-counting the bare-suffix file as both v1 and the next free slot**. The helper logic: bare-suffix `REF-<cat>-<id>.md` is version 1; the first call to `supersede_next_version` returns 2 (because no `-vN.md` files exist yet). The helper's `for f in ... -v*.md; do` loop only matches the explicitly-versioned successors, so the highest-of-1-and-zero-found is correctly 1, and N+1 is correctly 2.

The amend-prior-chunk function uses awk-into-tmpfile-then-mv rather than `sed -i` because BSD-sed (macOS) and GNU-sed disagree on the `-i` syntax. The awk form is portable across both.

The `superseded_by:` line is inserted after the existing `content_hash:` line (which always exists per the P02 chunk shape). Idempotency is checked by `grep -qF -e 'superseded_by: "<new-id>"'` before the awk pass — if the exact line is present, no-op.

The third extract assertion in the end-to-end verifier is the load-bearing idempotency-restored gate: after a supersede has fired, the now-current chunk_file (v2) holds the new content_hash, so the standard SKIPPED fast path resumes. The driver continues to produce zero-diff trees on subsequent runs against the unchanged-mutated source.

Expected verifier outputs: extract-supersede-shape reports `pass=10 fail=0`; extract-supersede-helper-shape reports `pass=6 fail=0`; supersede-chain-end-to-end reports `pass=5 fail=0`.

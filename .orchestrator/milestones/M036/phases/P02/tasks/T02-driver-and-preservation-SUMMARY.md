---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M036"
provides:
  - "scripts/knowledge/lib/extract-manifest.sh (pure manifest parser: extract_manifest_top_field, extract_manifest_doc_count, extract_manifest_doc_field, extract_manifest_resolve_tier — no top-level I/O, MEM004 pure-lib pattern); scripts/knowledge/lib/extract-binary-preservation.sh (pure helpers: preservation_sha256 with shasum/sha256sum probe fallback, preservation_size_bytes, preservation_copy_under_originals idempotent via sha256 match, preservation_above_cap, preservation_external_pointer_shape emitting file:// URI); scripts/knowledge/extract-reference.sh (driver — sources both T02 helpers + T03 lib/extract-tier-0-summary.sh, accepts --manifest/--reference-root/--originals-root/--summary-mode/--size-cap-bytes flags, iterates documents, computes content_hash, gates on prior content_hash for idempotency, preserves binaries under <originals-root>/<source>/<basename> OR records external_pointer when above cap, emits Tier 0 chunk frontmatter + body, dispatches Tier 1 via T03's extract_tier_1_via_registry helper, emits EXTRACTED:/SKIPPED: stdout contract); 4 verifiers under tools/verify/ (m036-p02-extract-driver-shape.sh — 10 checks: 3 file existence+executable + 7 token-presence; m036-p02-binary-preservation.sh — host-aware: SKIP on pdftotext/pandoc-absent, else 3 byte-identity checks; m036-p02-content-hash.sh — host-aware: SKIP on pdftotext/pandoc-absent, else 3 hash-equality checks; m036-p02-size-cap-external-pointer.sh — markdown-only with cap=1, asserts external_pointer present + binary not copied)"
requires:
  - "T01 (manifest contract SSOT, fixture manifest, sample.pdf/docx/md fixtures, .gitignore _originals/ entry); P00 (reference-source-types.yaml for default-tier resolution); P01 (registry.tsv read by driver — Tier 1 dispatch happens in T03)"
affects:
  - "T03 (authors lib/extract-tier-0-summary.sh which the driver sources for extract_tier_1_via_registry + generate_tier_0_summary; T03 verifiers exercise driver end-to-end on Tier 1 paths); T04 (acceptance harness + phase-suite aggregator gates the driver end-to-end)"
key_files:
  - "scripts/knowledge/extract-reference.sh, scripts/knowledge/lib/extract-manifest.sh, scripts/knowledge/lib/extract-binary-preservation.sh, tools/verify/m036-p02-extract-driver-shape.sh, tools/verify/m036-p02-binary-preservation.sh, tools/verify/m036-p02-content-hash.sh, tools/verify/m036-p02-size-cap-external-pointer.sh"
key_decisions:
  - "none"
patterns_established:
  - "Pure-lib extraction pattern (MEM004) carried into M036 P02: manifest parsing + binary preservation factored into sourceable helper libs under scripts/knowledge/lib/; driver scripts/knowledge/extract-reference.sh sources both + T03's lib/extract-tier-0-summary.sh and orchestrates per-doc work; helpers take args + emit to stdout / exit code only — no top-level I/O so they sourceable safely; AD-19 single-script-file shape for driver invocation (`bash scripts/knowledge/extract-reference.sh --manifest ...`) — internal grep|head|sed and awk pipelines are legal inside the script body because the classifier inspects only the *invocation* form (M036/P00/T03's MEM031 'validator-internal pipeline classifier-shape pass-through' pattern); idempotency via content_hash gate (driver reads existing chunk's `content_hash:` frontmatter; SHA-256 match → SKIPPED:, mismatch → re-emit); binary-preservation idempotency via sha256-match-then-skip in preservation_copy_under_originals (no redundant cp when source unchanged); shasum/sha256sum probe-and-fallback for cross-platform sha256 (BSD-macOS / GNU-Linux); cross-task verifier dependency pattern documented under Plan-Time Discipline rule 2 (T02's behavioural verifiers exercise properties that need T03's helper — verifiers authored in T02 alongside the driver they test, become green only after T03 lands the helper the driver sources; auto-loop's first-fail-retry handles ordering at execute time); host-tooling-aware SKIP carried from M036/P01 verifiers (probe `command -v pdftotext|pandoc` → emit `SKIP: <tool>-absent` + exit 0 informationally so aggregator counts as PASS); grep -F flag-safety: `grep -qF -e \"$pat\"` form required so token strings starting with `-` (e.g., `--manifest`) are not misinterpreted as flags by grep; `grep -qF \"$pat\"` is unsafe for any pattern that may begin with a dash (caught during T02 first-run verification, fix carried into the m036-p02-extract-driver-shape.sh checkpat helper)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P02/tasks/T02-driver-and-preservation-PLAN.md, .orchestrator/milestones/M036/phases/P02/tasks/T02-driver-and-preservation-PAYLOAD.md"
duration: "30m"
verification_result: "done_with_concerns"
completed_at: "2026-05-02T13:30:00Z"
---

T02 lands the M036 P02 extract driver scaffold + two pure helper libs (manifest parsing + binary preservation) + four shape/behavioural verifiers under `tools/verify/m036-p02-*`. The driver follows the MEM004 pure-lib extraction pattern: it sources two T02-authored helpers plus T03's not-yet-landed `lib/extract-tier-0-summary.sh`, orchestrates per-document work (content_hash gate → preservation OR external_pointer → Tier 1 dispatch (T03 wires) → Tier 0 summary (T03 wires) → chunk emission), and emits a structured `EXTRACTED:`/`SKIPPED:` stdout contract.

**What was built**:

- `scripts/knowledge/lib/extract-manifest.sh` (~60 lines) — pure manifest parser with four functions: `extract_manifest_top_field` (top-level scalar field accessor with quote-stripping), `extract_manifest_doc_count` (counts `cite_id`-keyed list entries), `extract_manifest_doc_field` (awk-driven Nth-document field accessor with current-record tracking), and `extract_manifest_resolve_tier` (default-tier lookup against `references/reference-source-types.yaml` SSOT). Bash 3.2 / POSIX-sh; no associative arrays; no jq.

- `scripts/knowledge/lib/extract-binary-preservation.sh` (~80 lines) — five pure helpers: `preservation_sha256` (probes shasum then sha256sum; fails clearly if neither), `preservation_size_bytes` (POSIX `wc -c`), `preservation_copy_under_originals` (mkdirs `<root>/<source-id>/`, idempotent — sha256-matching destination short-circuits the copy), `preservation_above_cap` (size comparison with cap), `preservation_external_pointer_shape` (emits `file://<absolute-path>` URI for above-cap binaries; `#Q-9` future-extensible to S3/other URI schemes).

- `scripts/knowledge/extract-reference.sh` (~140 lines) — the driver. `set -eu`. Sources both T02 helpers + T03's `lib/extract-tier-0-summary.sh`. Resolves `ROOT` via `${ORCHESTRATOR_ROOT:-$(cd "$HERE/../.." && pwd)}`. Parses 5 flags. Reads `size_cap_bytes` from manifest top-level (defaults to 10 MiB). Iterates documents 1..DOC_COUNT, resolving missing `tier:` via `extract_manifest_resolve_tier`, applying CLI overrides for summary_mode + size_cap. Per doc: resolves source path (absolute or manifest-relative); computes sha256 + size; checks chunk-file existence + `content_hash:` for idempotency (matches → `SKIPPED: <id> reason=unchanged`); above cap → records external_pointer; below cap → calls `preservation_copy_under_originals`; tier ≥ 1 → calls T03's `extract_tier_1_via_registry`; calls T03's `generate_tier_0_summary`; emits Tier 0 chunk frontmatter (schema_version, type, milestone, category, chunk_id, cite_id, source, published, version, tier, content_hash, size_bytes, optional external_pointer, summary_mode) + body; emits `EXTRACTED: <id> tier=<n> bytes=<n> hash=<8-char-prefix>`.

- Four verifiers under `tools/verify/m036-p02-*`:
  - `extract-driver-shape.sh` (10 checks) — file existence + executable for driver + 2 libs; token presence for `--manifest`, `EXTRACTED:`, `SKIPPED:`, `extract-manifest.sh`, `extract-binary-preservation.sh`, `extract_manifest_doc_count`, `preservation_sha256`. PASSes on T02 close (shape-only).
  - `binary-preservation.sh` — drives extract-reference.sh end-to-end on the fixture manifest in a mktemp workspace, asserts byte-identity for each of the three originals at `_originals/<source>/<basename>`. Host-aware: SKIPs on pdftotext-absent or pandoc-absent.
  - `content-hash.sh` — drives the same end-to-end, asserts each chunk's `content_hash:` frontmatter matches `shasum -a 256` of the source. Host-aware SKIP.
  - `size-cap-external-pointer.sh` — stages a synthetic single-doc manifest with `size_cap_bytes: 1` against `sample.md`, asserts `external_pointer:` recorded in the emitted chunk and the binary is NOT copied. Markdown-only — no host-tool dependency.

**Verification result — DONE_WITH_CONCERNS (cross-task ordering, expected per plan)**:

- Truth-Check verifiers (T01-authored) PASS unchanged: `m036-p02-manifest-contract-shape.sh` (13/13), `m036-p02-fixture-manifest-shape.sh` (7/7), `m036-p02-fixture-corpus-shape.sh` (4/4).
- T02 shape verifier `m036-p02-extract-driver-shape.sh`: PASS (10 checks, fail=0). One mid-run fix applied: `grep -qF "$pat"` was misinterpreting `--manifest` as a grep flag; corrected to `grep -qF -e "$pat"` so leading-dash tokens are token-safe. Pattern recorded in `patterns_established`.
- T02 behavioural verifiers ON THIS HOST (pandoc absent):
  - `m036-p02-binary-preservation.sh` → `SKIP: pandoc-absent`, exit 0 (host-aware skip working as designed).
  - `m036-p02-content-hash.sh` → `SKIP: pandoc-absent`, exit 0 (same).
  - `m036-p02-size-cap-external-pointer.sh` → FAIL with stderr `lib/extract-tier-0-summary.sh: No such file or directory` because the driver sources T03's `lib/extract-tier-0-summary.sh` which has not been authored yet. **This is the cross-task ordering scenario explicitly anticipated by the plan** (PLAN/PAYLOAD constraints section, "Plan-Time Discipline rule 2" note: "T02's verifiers exercise behavioural properties that need T03's helper, but the verifiers are *authored* in T02 alongside the code-they-test. They will be re-run after T03 closes; the auto-loop's first-fail-retry semantics handle the ordering at execute time."). Resolution comes when T03 lands `lib/extract-tier-0-summary.sh` providing `extract_tier_1_via_registry` + `generate_tier_0_summary`.

**Per-host expectation post-T03 close**:
- pdftotext + pandoc present → all three behavioural verifiers green (driver runs end-to-end against the 3-doc fixture corpus + size-cap synthetic).
- pdftotext or pandoc absent → `binary-preservation.sh` + `content-hash.sh` SKIP cleanly, `size-cap-external-pointer.sh` (no host-tool dep) PASSes.
- shasum or sha256sum present (one or both — overwhelmingly always one of these on macOS / Linux) → preservation_sha256 produces digest cleanly.

**Forward notes**:
- T03 must author `scripts/knowledge/lib/extract-tier-0-summary.sh` exporting `extract_tier_1_via_registry(<src-abs> <text-out-path> <registry-tsv-path>)` (looks up adapter via registry, invokes it, redirects stdout to text-out-path) and `generate_tier_0_summary(<mode> <category> <cite_id> <operator-summary> <tier>)` (returns the summary body string per mode — operator/stub/auto).
- The `chunk_id` field in emitted chunks uses the doubled-cite-id pattern `REF-<category>-<cite_id>` matching the T01 fixture cite_ids (e.g., `REF-cms-rule-cms-rule-fixture-01`); this matches the verifier path expectations in `content-hash.sh` (`REF-cms-rule-cms-rule-fixture-01.md`).
- The `extract_manifest_resolve_tier` function in `extract-manifest.sh` was patched at author-time to use a 4-arg `sub(re, repl, line)` form so the working-line variable is explicit; the plan's 2-arg `sub(re, repl)` (which mutates `$0` implicitly) also works in awk but the explicit form is more obvious to read.

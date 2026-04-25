---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M020"
goal: "Surface a `Review Queue:` section in `scripts/orchestrator/status.sh` that lists pending-review (`status: candidate`) knowledge entries, grouped by cluster (via the P05 `cluster_compute` helper), with per-cluster topic/count/oldest-age summaries and a `(stale)` flag for entries older than the FR-4 staleness threshold (default 14 days per OQ-1; preference-overridable via `staleness_threshold:`)."
demo_sentence: "Running `bash scripts/orchestrator/status.sh --root <fixture-root>` against a fixture orchestrator root whose `knowledge/` tree contains five `status: candidate` entries grouping into two clusters emits, on stdout, a `Review Queue: 2 clusters, 5 entries awaiting review` line followed by one indented `cluster=<C8hex> topic=<topic> count=<N> oldest_age=<days>d` summary per cluster (two such lines, total); entries whose age exceeds the resolved staleness threshold are flagged with a trailing `(stale)` marker on their cluster summary line; an empty review queue (no candidates) emits exactly `Review Queue: empty` and no per-cluster lines."
risk: "low"
depends_on: ["P03"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19 / MEM031 / continue.md lessons (P01 + P02 + P03), Truth Check
     commands MUST use single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no
     process substitution. Verifier scripts referenced here are produced
     by the listed task; the phase-level Verification Commands block at
     the bottom is the rollup. -->

- `scripts/knowledge/compute-staleness.sh` exposes a `--review-queue --root <orch-root>` mode that walks `<orch-root>/../knowledge/**/MEM*.md` (or `--knowledge-root <path>` override), filters to `status: candidate`, groups by cluster via the P05 `lib/cluster.sh::cluster_compute` helper, and emits one `cluster_id=<C8hex> topic=<topic> count=<N> oldest_age=<days>` line per cluster on stdout; emits exactly `EMPTY` on stdout when no candidates exist; exits 0 in both cases.
  - Check: `bash scripts/verify/m020-p04-compute-staleness-review-queue.sh`
- `scripts/knowledge/compute-staleness.sh --review-queue` flags clusters whose oldest member's `created_at:` (with `last_verified:` fallback) is older than the resolved staleness threshold (default 14 days per OQ-1; reads `.orchestrator/preferences.yml::staleness_threshold` integer-scalar override when present and non-malformed) by appending ` stale=true` to that cluster's summary line; well-formed clusters emit ` stale=false`.
  - Check: `bash scripts/verify/m020-p04-compute-staleness-stale-flag.sh`
- `scripts/orchestrator/status.sh` emits a `Review Queue:` section after the existing `MILESTONE:` / `STATE:` / `PHASE:` lines: when the queue is non-empty, the section's first line matches `^Review Queue: <N> clusters, <M> entries awaiting review$` (N = cluster count, M = total candidate count) followed by one indented per-cluster summary line per cluster prefixed with two-space indent; when the queue is empty, the section is exactly the single line `Review Queue: empty`.
  - Check: `bash scripts/verify/m020-p04-status-review-queue-section.sh`
- `scripts/orchestrator/status.sh` Review-Queue rendering surfaces the `(stale)` marker on per-cluster summary lines whose underlying compute-staleness output carries `stale=true`; non-stale cluster lines do NOT carry the marker; the marker text is the literal `(stale)` (parenthesised, lowercase) at end-of-line.
  - Check: `bash scripts/verify/m020-p04-status-stale-marker.sh`
- `scripts/orchestrator/status.sh` Review-Queue computation is read-only with respect to `knowledge/**` and `.orchestrator/execution-log.jsonl` — invoking status.sh against a fixture root does not modify any file under `<fixture-root>/../knowledge/` or append any line to `<fixture-root>/execution-log.jsonl` (FR-8 / CON-1 dispatch read-only invariant).
  - Check: `bash scripts/verify/m020-p04-status-review-queue-readonly.sh`
- `scripts/orchestrator/status.sh` preserves its pre-P04 output prefix byte-equivalently — the existing `MILESTONE:`, `STATE:`, `PHASE: P## <state>` lines, their order, and their content remain unchanged; the Review-Queue section is strictly appended after the last `PHASE:` line of the last milestone (CON-4 surgical-precision surface preservation).
  - Check: `bash scripts/verify/m020-p04-status-prefix-preserved.sh`
- `tests/test-status-review-queue.sh` exists, is executable, and exits 0 covering SC-3 (five candidates in two clusters → `Review Queue: 2 clusters, 5 entries`), the empty-queue case (zero candidates → `Review Queue: empty`), and the stale-flag case (a candidate created more than 14 days before the test reference date → `(stale)` marker on its cluster line).
  - Check: `bash tests/test-status-review-queue.sh`

### Artifacts

- `scripts/knowledge/compute-staleness.sh` (min 200 lines, contains "review-queue")
- `scripts/orchestrator/status.sh` (min 110 lines, contains "Review Queue")
- `tests/test-status-review-queue.sh` (min 200 lines, contains "Review Queue")
- `scripts/verify/m020-p04-compute-staleness-review-queue.sh` (min 60 lines, contains "cluster_id")
- `scripts/verify/m020-p04-compute-staleness-stale-flag.sh` (min 50 lines, contains "stale=true")
- `scripts/verify/m020-p04-status-review-queue-section.sh` (min 60 lines, contains "Review Queue")
- `scripts/verify/m020-p04-status-stale-marker.sh` (min 50 lines, contains "(stale)")
- `scripts/verify/m020-p04-status-review-queue-readonly.sh` (min 50 lines, contains "knowledge")
- `scripts/verify/m020-p04-status-prefix-preserved.sh` (min 50 lines, contains "MILESTONE")

### Key Links

- `scripts/orchestrator/status.sh` → `scripts/knowledge/compute-staleness.sh` (status.sh invokes compute-staleness.sh `--review-queue` as a subprocess; comment in status.sh names the file by basename)
- `scripts/knowledge/compute-staleness.sh` → `scripts/knowledge/lib/cluster.sh` (compute-staleness.sh sources cluster.sh for `cluster_compute`; comment in compute-staleness.sh names the file)
- `scripts/knowledge/compute-staleness.sh` → `scripts/knowledge/lib/frontmatter.sh` (compute-staleness.sh sources frontmatter.sh for `fm_read_status` / `fm_field` reads of `created_at:` / `topic:` / `tags:`; comment names the file)
- `tests/test-status-review-queue.sh` → `scripts/orchestrator/status.sh` (test invokes the script under test verbatim)

## Tasks

### T01: compute-staleness.sh extension — `--review-queue` mode

See `tasks/T01-compute-staleness-review-queue-PLAN.md`.

Lands the FR-4 review-queue computation as a new mode of the existing `scripts/knowledge/compute-staleness.sh` script (in-place additive extension; preserves the legacy staleness-report invocation byte-equivalent per CON-4). New mode is gated on `--review-queue` flag at top of the script. When set:

1. Resolve knowledge root from `--knowledge-root <path>` (preferred) or default to `<repo-root>/knowledge`.
2. Walk `<knowledge-root>/**/MEM*.md`, filter to entries whose `status:` is exactly `candidate` (per MEM031 closed enum; pre-M020 entries default to graduated and are excluded).
3. Source `scripts/knowledge/lib/cluster.sh` and call `cluster_compute <knowledge-root> <similarity-threshold>` to group candidates into clusters; the threshold defaults to 0.7 per AD-5 + reads `.orchestrator/preferences.yml::similarity_threshold` if present and parseable (preference-resolution is best-effort and falls back to 0.7 on any malformation; matches the P05 + P06 documented contract).
4. For each cluster, compute: count of members, oldest-member-age (days since `created_at:` of the lexicographically-first member's frontmatter, falling back to `last_verified:` when `created_at:` is missing — both fields are documented in MEM013), topic (read `topic:` frontmatter field of the canonical/oldest member; empty string when missing).
5. Resolve the staleness threshold: read `.orchestrator/preferences.yml::staleness_threshold` integer (default 14 per OQ-1; malformed values fall back to 14 with a single-line stderr diagnostic; preferences-file absent is silently treated as default).
6. For each cluster summary line, emit on stdout: `cluster_id=<C8hex> topic=<topic-or-empty> count=<N> oldest_age=<days> stale=<true|false>` (single line per cluster, sorted by cluster_id ascending).
7. When the candidate set is empty, emit exactly `EMPTY` on stdout and exit 0.

### T02: status.sh Review-Queue section

See `tasks/T02-status-review-queue-section-PLAN.md`.

Extends `scripts/orchestrator/status.sh` in place to invoke T01's `compute-staleness.sh --review-queue` as a subprocess after the existing milestone/phase enumeration, parses its stdout, and renders the Review-Queue section per the FR-4 contract:

- Empty: emit exactly `Review Queue: empty` (single line).
- Non-empty: emit `Review Queue: <N> clusters, <M> entries awaiting review` followed by one indented (`  `) summary line per cluster of the form `  cluster=<C8hex> topic=<topic> count=<N> oldest_age=<days>d` with a trailing ` (stale)` token on stale clusters (parenthesised, lowercase, separated by a single space).
- Failure-tolerant: if T01 exits non-zero or emits unparseable output, status.sh emits `Review Queue: unavailable` and continues (does not propagate non-zero exit). One-line stderr diagnostic captures the cause.
- Read-only: status.sh writes nothing to `knowledge/**` or to `.orchestrator/execution-log.jsonl` per FR-8 / CON-1.
- Surface preservation: pre-P04 `MILESTONE:` / `STATE:` / `PHASE:` lines remain byte-equivalent; the Review-Queue section is strictly appended.

### T03: per-truth contract verifiers (`scripts/verify/m020-p04-*.sh`)

See `tasks/T03-truth-verifiers-PLAN.md`.

Ships the six per-truth verifier scripts under `scripts/verify/`, each exercising exactly one Truth from the Must-Haves block above. All verifiers use tempdir + trap-EXIT-rm-rf fixture isolation so the live `knowledge/**` tree and the live `.orchestrator/execution-log.jsonl` are never touched. AD-19 / MEM001 conventions: each verifier is a single-script-file invocation; internals may use heredocs/pipes since the harness shape-guard inspects only directly-invoked Bash tool-call shapes (P03/T04 carry-forward).

### T04: integration test (`tests/test-status-review-queue.sh`) — SC-3 end-to-end

See `tasks/T04-integration-test-PLAN.md`.

Cross-cutting end-to-end test exercising `scripts/orchestrator/status.sh` directly across the three SC-3-relevant scenarios:

1. **Five-candidate / two-cluster fixture**: assert stdout contains `Review Queue: 2 clusters, 5 entries awaiting review` plus exactly two indented per-cluster summary lines.
2. **Empty queue fixture**: zero candidate entries; assert stdout contains exactly `Review Queue: empty` and no per-cluster lines.
3. **Stale-flag fixture**: a candidate whose `created_at:` is 30 days before the test reference date; assert its cluster line carries the trailing ` (stale)` marker.

Asserts byte-equivalent prefix preservation by re-running status.sh against a fixture without any candidates and diffing the prefix bytes against a recorded golden capture from the same fixture pre-P04.

## Task Dependencies

```
T01 ──→ T02 ──→ T04
              │
              ▼
T03 ──────── (T03 references both T01 and T02 outputs; runs after T01+T02 land)
```

- **T01** ships the compute-staleness.sh `--review-queue` mode. No upstream task dependencies beyond P03 (`status: candidate` vocabulary) and P05 (`lib/cluster.sh::cluster_compute`, both already shipped on main).
- **T02** extends `status.sh` and consumes T01's stdout contract. Must wait for T01.
- **T03** ships the six per-truth verifiers; each verifier exercises either T01 (compute-staleness contract) or T02 (status.sh rendering / readonly / prefix preservation). T03 lands after both T01 and T02.
- **T04** depends on T02 — exercises the full status.sh path end-to-end.

Auto-loop dispatch order: T01 → T02 → T03 → T04 (sequential). T03's two compute-staleness verifiers could in principle land in parallel with T02 if T01 ships first, but the marginal throughput gain is small and not load-bearing.

## Verification Commands

<!-- Cross-task invariants and phase-level rollups. Per-task verifiers
     live under each task's own ## Verification block; the commands here
     are the phase-completion gate that runs after T04 ships. -->

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P04
bash scripts/verify/m020-p04-compute-staleness-review-queue.sh
bash scripts/verify/m020-p04-compute-staleness-stale-flag.sh
bash scripts/verify/m020-p04-status-review-queue-section.sh
bash scripts/verify/m020-p04-status-stale-marker.sh
bash scripts/verify/m020-p04-status-review-queue-readonly.sh
bash scripts/verify/m020-p04-status-prefix-preserved.sh
bash tests/test-status-review-queue.sh
```

All eight commands must exit 0. The first is the must-haves rollup; the next six are per-truth Tier-1 verifiers; the last is the SC-3 integration test.

## Files Likely Touched

- `scripts/knowledge/compute-staleness.sh` (modify — additive `--review-queue` mode; preserve legacy staleness-report invocation byte-equivalent per CON-4)
- `scripts/orchestrator/status.sh` (modify — append Review-Queue section after existing per-milestone enumeration; preserve `MILESTONE:` / `STATE:` / `PHASE:` line shapes byte-equivalent per CON-4)
- `tests/test-status-review-queue.sh` (create)
- `scripts/verify/m020-p04-compute-staleness-review-queue.sh` (create)
- `scripts/verify/m020-p04-compute-staleness-stale-flag.sh` (create)
- `scripts/verify/m020-p04-status-review-queue-section.sh` (create)
- `scripts/verify/m020-p04-status-stale-marker.sh` (create)
- `scripts/verify/m020-p04-status-review-queue-readonly.sh` (create)
- `scripts/verify/m020-p04-status-prefix-preserved.sh` (create)

No files under `knowledge/**` are touched by P04 task code (only by transient verifier and test tempdirs). No files under `.orchestrator/memory/`, `.orchestrator/DECISIONS.md`, or any pre-existing knowledge convention/pattern/lesson are modified — P04 is a pure read-side surface lift over the schema P01 + P03 already authorized; no schema evolution.

JSONL emission is intentionally NOT in P04's scope. Status.sh and compute-staleness.sh `--review-queue` are read-only by FR-8 / CON-1. M019 Tier 2+3 (downstream) consumes the existing P03 `knowledge_graduate` / `knowledge_archive` records for review-queue throughput metrics — no new event types are added in P04.

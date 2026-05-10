---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M018"
provides:
  - "scripts/util/cache-prune.sh — single-file Tier 1 tool-result cache eviction utility; --max-age <N>d, <N>h, or <N>m flag with 7d default; --dry-run flag; mtime-based pruning; reads compression.tier1.cache_dir from .orchestrator/config.yml with fallback to .orchestrator/cache/tool-results/; idempotent (steady-state re-run is a no-op); structured PASS-style stdout (PRUNED:/WOULD-PRUNE:/SUMMARY:) including pruned/kept/total/bytes_freed counters"
requires:
  - "T01 (cache_dir config key + tier1 cache writes); compression.tier1.cache_dir at .orchestrator/config.yml"
affects:
  - "P03/T03 verifiers (m018-p03-cache-prune.sh consumes this script); operator workflows (manual cache hygiene); future M018 follow-up reference-aware preservation extends this surface"
key_files:
  - "scripts/util/cache-prune.sh"
key_decisions:
  - "mtime-only prune correct for M018 cache surface (full SHA-256 hex keys + dispatch-time-only writes — collisions impossible); reference-aware preservation deferred as documented M018 follow-up; single-level glob walk explicitly forbids sub-directory recursion so future tier-3-originals/ co-tenants stay untouched (Constitution VI); cwd-first project-root resolution with $0-fallback so verifiers and operators can override via fixture trees while standalone invocation still works; macOS/Linux stat flavor probed once at startup; bytes_freed surface added beyond payload spec for operator visibility"
patterns_established:
  - "cwd-first then $0-fallback project-root resolution for util scripts that need to be testable in fixture trees but also work standalone; stat-flavor probe via stat -f %m on $0 at startup (single detection, used uniformly thereafter); structured stdout dual record stream (per-action PRUNED:/WOULD-PRUNE: lines + final SUMMARY: aggregate) extending MEM001's PASS/FAIL/SUMMARY family for destructive utilities"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P03/tasks/T02-cache-prune-PAYLOAD.md;scripts/util/cache-prune.sh;.orchestrator/config.yml"
duration: "20"
verification_result: "pass"
completed_at: "2026-04-28T02:46:43Z"
---

T02 ships the Tier 1 tool-result cache eviction utility called out in spec FR-16 and the M018/P03 roadmap demo sentence. The script is single-file, bash 3.2 compatible, and AP-009 clean (no compound chains > 2, no plain subshells, no $(... pipe ...) shapes). It accepts --max-age in <N>d / <N>h / <N>m form (default 7d), parses the unit/numeric split via parameter expansion (no regex), and converts to seconds with integer arithmetic. Project root is resolved cwd-first then $0-fallback so the T03 verifier (m018-p03-cache-prune.sh) can drive it against a fixture tree without leaking into the real .orchestrator/cache/. The cache root is read from .orchestrator/config.yml compression.tier1.cache_dir via a single awk pass that tracks indent entry/exit on the tier1 block; missing config or missing key falls back to the spec default .orchestrator/cache/tool-results/.

Pruning walks the cache root one level deep with a bash glob (cache filenames are SHA-256 hex digests, no spaces). Sub-directories are deliberately skipped — a Constitution VI invariant so future tier-3-originals/ co-tenants under the same cache root cannot be accidentally clobbered. mtime is read via macOS stat -f %m or GNU stat -c %Y, detected once at startup. Files older than now - max_age_seconds are removed (or reported via WOULD-PRUNE: lines under --dry-run); newer files are kept. The aggregate SUMMARY: line reports pruned, kept, total, and bytes_freed — the bytes_freed counter is an operator-visibility extension beyond what the payload spec mandated, kept cheap because we already had to stat each file for mtime.

Smoke-tested against a tmp fixture tree with one ancient file (touch -t 202001010000) and one fresh file: first call prunes 1 + keeps 1 + reports bytes_freed=4; second call shows pruned=0 (idempotent). --dry-run on a fresh ancient file emits WOULD-PRUNE: without removing. 60m and 48h unit parsing both work. Missing cache directory is a graceful no-op with a single SUMMARY: line. Malformed --max-age (e.g. 'abc', '5y') exits 1 with a diagnostic on stderr. bash -n is clean. The companion T03 verifier (m018-p03-cache-prune.sh, lands later in P03) will codify these scenarios as PASS asserts. Reference-aware preservation (the second clause of US-3 acceptance scenario 5 — preserving entries still referenced in execution-log.jsonl) is explicitly out of scope for M018 per the roadmap simplification; mtime-only is correct given the SHA-256-hex cache key surface and dispatch-time-only writes.

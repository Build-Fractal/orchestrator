---
schema_version: "1.0"
type: evaluation
milestone: "M035"
feature_ref: "039-packaging-distribution"
feature_spec: "specs/039-packaging-distribution/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-07T00:00:00Z"
metrics_source: "raw_spec"
---

# M035 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: /orchestrator-discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 10 |
| Acceptance scenarios | 30 |
| Functional requirements | 16 |
| Success criteria | 16 |
| Constraints | 7 |
| Open Questions (routed) | 9 |
| Estimated SDD flows | 7 (P00–P06) |

> Chunks-first metrics path probed `spec_chunks_present=true` but the chunks belong to M016 (autonomous hardening, `source_unit` confirms) — not M035. Falling back to raw-spec regex; recorded as `metrics_source: raw_spec`.

## Reasoning

M035 (packaging & distribution) is unambiguously Tier C. The spec carries 10 user stories spanning two distinct work layers — P00/P01 pre-launch dev-ergonomics (US-1 `--mode=symlink`, US-2 version-drift warning, US-3 bash 3.2 exit-code, US-4 installer `.gitignore`, US-5 namespace cohort rename) and P02–P06 launch-event publishing pipelines (US-6 npm, US-7 homebrew, US-8 curl-pipe-bash + GH release automation, US-9 install-script integrity, US-10 multi-source `orchestrator:update` dispatch). Each layer composes a complete SDD flow with cross-channel byte-equivalence (CON-5), CI secrets hygiene (CON-6), and a multi-week dependency chain — work this complex cannot fit one phase, one context, or one specify-pass.

Two additional signals reinforce Tier C:

1. **Conversus gate verdict is BLOCK** with 9 surviving disputes routed as Open Questions `#Q-G1..#Q-G9` for resolution at `/orchestrator-discuss` (P0: MIT-1..MIT-5) and plan-phase (P1: MIT-6..MIT-8, P2: MIT-9). Five P0 mitigations require operator-level architectural decisions (repo rename strategy, CON-5 exclusion enumeration, FR-7 cross-tree co-ship scope, `--mode=auto` reconciliation, FR-3 SHA-absent fallback). Tier B does not have a `discuss` gate; these questions cannot land at the right stage without Tier C orchestration.

2. **Cross-milestone dependencies** are explicit in the spec: M029 renders the drift warning datum (M035 contributes), M025's installer-uninstall manifest must extend to symlink-mode (FR-1 boundary), M033 friendly-tester pass `#Q-11` overlaps early M035 phases, and M037 P03 wiki-stub-drift paper-cut (filed today, `papercut-wiki-stub-drift.md`) folds into M035 P00/P01 scope. Cross-phase coordination is the defining Tier C capability.

## Complexity Factors

- **Two-layer sequencing**: P00/P01 (pre-launch dogfood ergonomics) ships independently of P02–P06 (launch event). Layer 1 is launch-blocking only because Layer 2 depends on it; Layer 1's own dogfood payoff predates launch.
- **Cross-channel byte-equivalence (CON-5)**: npm tarball, homebrew bottle, and curl-pipe-bash install must produce byte-identical runtime layouts (verified by hash). This is a Constitution Principle XVI compliance test surface; every phase that touches an install channel must pass it.
- **CI secrets hygiene (CON-6)**: publishing pipelines run secret-bearing steps only on tag-push events. PR workflows must not run them. This is the launch security baseline.
- **External dependencies**: GitHub Pages, npm registry, homebrew tap repo, GPG/sigstore signing infrastructure. P00 includes a discovery slot to enumerate exact external dependencies and version requirements before P02 begins.
- **Routed Open Questions (9)**: P0 `#Q-G1..#Q-G5` resolve at discuss; P1 `#Q-G6..#Q-G8` and P2 `#Q-G9` resolve at the relevant plan-phase. The discuss step is therefore a non-trivial gate, not ceremonial.
- **Pre-existing paper-cut overlap**: Layer 1 of `papercut-wiki-stub-drift.md` (PBJ-central round-5 dogfood, 2026-05-07) folds into M035 P00 or P01 scope — surfaces as Open Question in the discuss step for placement decision.
- **Operator-targeted runtime constraints**: macOS bash 3.2 exit-code propagation (US-3) is platform-specific hardening that requires fixture-based regression tests on both bash 3.2 and bash 4+; the test surface is non-trivial.
- **Namespace cohort rename (US-5)**: ~71 occurrences of `speckit.orchestrator.*` across 15 files. Must land before P02 (npm publish) because v1's published name determines the canonical command-cohort prefix forever. Sequencing pressure is real.

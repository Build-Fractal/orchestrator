---
schema_version: "1.0"
type: phase-summary
id: "M042/P01"
parent: "M042"
milestone: "M042"
phase: "P01"
verification_result: "pass"
completed_at: "2026-05-30T00:00:00Z"
---

# M042 / P01 — Deterministic gate engine + adapter + artifact contract

Shipped the zero-LLM corpus-exhaustion floor:

- `scripts/knowledge/corpus-exhaustion-sweep.sh` — deterministic term extraction
  (structured IDs, ISO dates, quoted phrases, significant tokens minus
  stopwords) + grep sweep over a configurable store manifest + per-question
  artifact (CLEAN / HITS / DROPPED / KEPT / IRREDUCIBLE-WITH-CAVEAT) + top-level
  PASS|BLOCK. Bash 3.2; reproducible (`--generated-at`, no `date`/`$RANDOM`);
  CON-3 caveat on unreachable required stores; CON-4 hit cap noted in-artifact.
- `scripts/dispatch/adapters/tool/corpus-gate.sh` — `check`/`gate`/`parse-verdict`
  with the conversus exit-code contract (0 PASS/SKIP · 2 BLOCK · 1 error);
  owns enabled/manifest/strict policy + fail-open degradation.
- `templates/corpus-store-manifest.yml` (bundled default; only DECISIONS.md +
  constitution.md are `required: true`) + `templates/corpus-exhaustion-artifact.md`.
- `corpus_exhaustion.{enabled,store_manifest_path,intensity_floor}` keys in
  `read-config.sh` (detective.* nested-block pattern) + config-default block.
- `commands/corpus-gate.md` + `packaging/skills/orchestrator-corpus-gate.md`.

Verification: `tools/verify/m042-p01-acceptance-battery.sh` — SC-1..SC-6,
`pass=8 skip=0 fail=0`.

---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M026"
goal: "Flip the orchestrator's default Conversus integration to OSS with a first-class paid escape hatch: edition detection via CONVERSUS_EDITION env var + pip-show metadata fallback (single-venv reality from P01 parity addendum, supersedes path-based detection); JSONL edition field wired additively; dual-edition regression test with skip-on-429 posture for OSS-Anthropic per OLLAMA-PROBE.md; adapter gate-verdict reliability bundle (POST-P01-FINDINGS F1/F2/F3 — extract rationale from verdict prose, prefer arbiter/resolution.md, auto-preflight CONVERSUS_PROVIDER=claude-code under OAuth) to close OQ-16 false-PASS on claude-code; all adapter invariants CON-1..CON-5 preserved; dual-write Recent Changes to CLAUDE.md + AGENTS.md."
demo_sentence: "Operator runs `bash scripts/dispatch/adapters/tool/conversus.sh check` on a system with the OSS pipx install and sees stdout containing `edition=oss reason=<env-override|metadata-probe|fallback>`. Setting `CONVERSUS_EDITION=paid` on the same system reports `edition=paid reason=env-override`. An `orchestrator:specify` Full-intensity invocation that reaches the conversus gate emits a `conversus_gate_invocation` JSONL record with `\"edition\":\"oss\"`. `CONVERSUS_INTEGRATION=1 bash tests/test-conversus-adapter-shim.sh` passes the dual-edition block with OSS-Anthropic branch cleanly annotating `SKIP: known-upstream-429 (OSS lacks PR #29)` and paid branch reporting `SKIP: paid build not installed`. `bash scripts/verify/m026-p02-phase-suite.sh` exits 0 with `SUMMARY: m026-p02-phase-suite.sh pass=N fail=0`."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

<!-- Every Check uses single-script-file shape per AD-19. All verification
     logic lives in scripts/verify/m026-p02-*.sh. Adapter changes preserve
     CON-1..CON-5; CON-5 read-only-on-conversus-trees still applies
     (no writes to ~/Sites/conversus* trees). -->

### Truths

- `scripts/dispatch/adapters/tool/conversus.sh` emits an `edition=<oss|paid|unknown>` line and a `reason=<env-override|metadata-probe|fallback|path|home|stub|command-v>` line on `check` stdout in addition to the existing `available=` and `conversus_path=` lines (FR-1/FR-3). When `CONVERSUS_EDITION=oss|paid` is set, the edition line matches the env-var value with `reason=env-override`. When unset and the `conversus` pipx venv's `pip show conversus` `Home-page:` contains `conversus-oss`, the edition line is `oss` with `reason=metadata-probe`. When the binary is resolved via `CONVERSUS_STUB`, `CONVERSUS_HOME`, or `command -v`, `reason` matches the resolution path and `edition=unknown` unless the venv metadata can still be probed.
  - Check: `bash scripts/verify/m026-p02-edition-detection-contract.sh`

- `scripts/dispatch/adapters/tool/conversus.sh` preserves the 0/1/2 exit-code contract, the full env-var set (`CONVERSUS_STUB`, `CONVERSUS_STUB_VERDICT`, `CONVERSUS_HOME`, `CONVERSUS_STRICT`, `CONVERSUS_PROVIDER`, `CONVERSUS_RUN_OUTPUT_DIR`, `CONVERSUS_GATE_TODO_THRESHOLD`, `CONVERSUS_GATE_SKIP_TODO_CHECK`, `CONVERSUS_INTEGRATION`), the D019 TODO pre-flight block, the stub-mode fixture paths, the `gate-result.md` frontmatter key-set (`verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`), and the filename-routed adapter auto-discovery pattern (MEM008/MEM018). No Bash 3.2 regressions introduced (no `declare -A`, no `mapfile`/`readarray`, no process substitution). Satisfies CON-1..CON-3.
  - Check: `bash scripts/verify/m026-p02-adapter-invariants.sh`

- `scripts/integrations/github-common.sh::emit_conversus_gate_record` and the inline JSONL emission at `scripts/specify/specify.sh` line 533 include an `"edition"` field immediately adjacent to `"adapter_version"` in every `conversus_gate_invocation` record (FR-4). The field value is populated from the adapter's resolver output and takes one of `oss`, `paid`, `unknown` (never empty, never missing). Pre-existing JSONL readers (M019 Tier 1) are unaffected — the addition is purely additive per AD-4.
  - Check: `bash scripts/verify/m026-p02-jsonl-edition-field.sh`

- `tests/test-conversus-adapter-shim.sh` gains a `CONVERSUS_INTEGRATION=1`-gated dual-edition block that exercises both editions when both are installed. Under current operator state (OSS installed, paid uninstalled per OLLAMA-PROBE.md), the OSS-Anthropic branch emits `SKIP: known-upstream-429 (OSS lacks PR #29)` and the paid branch emits `SKIP: paid build not installed`. Both SKIPs are visible-skip (annotated), not silent-skip, and do not cause the test to fail. The stub-mode path (existing sections 1, 1b, 2) remains untouched.
  - Check: `bash scripts/verify/m026-p02-dual-edition-test-shape.sh`

- `scripts/dispatch/adapters/tool/conversus.sh` resolves gate-result rationale from the synthesis file's verdict text when present, falling back to the synthesized-from-fields formula only when neither a `## Verdict` section nor `arbiter/resolution.md` is extractable (POST-P01-FINDINGS F1 complete). When `${_run_output_dir}/arbiter/resolution.md` exists, its first paragraph is preferred as the rationale source (F2). Under Anthropic-OAuth auth (detected from `~/.conversus/auth.json` shape or absence of `ANTHROPIC_API_KEY`), the adapter auto-sets `CONVERSUS_PROVIDER=claude-code` with a single-line stderr warning before invocation, unless the operator explicitly set `CONVERSUS_PROVIDER` (F3). Closes OQ-16 (false-PASS on claude-code).
  - Check: `bash scripts/verify/m026-p02-gate-verdict-reliability.sh`

- `CLAUDE.md` and `AGENTS.md` each contain a matching M026/P02 Recent Changes fragment under the marker-bounded `orchestrator:recent-changes` region. The fragments name the resolver flip (OSS primary), the `CONVERSUS_EDITION` env var, and the gate-verdict-reliability bundle. Dual-writing is performed via `scripts/util/dual-write-runtime-md.sh`, not inline edits. Existing M026/P01 fragment is preserved; the new fragment appears below it in reverse-chronological order as the file convention dictates.
  - Check: `bash scripts/verify/m026-p02-recent-changes.sh`

- `bash scripts/verify/m026-p02-phase-suite.sh` invokes every P02 verify script in dependency order, tallies pass/fail, emits a single `SUMMARY: m026-p02-phase-suite.sh pass=N fail=0` line, and exits 0 iff every gate passes. Pattern mirrors `scripts/verify/m026-p01-phase-suite.sh`. Bash 3.2 compatible; AD-19 single-script-file shape.
  - Check: `bash scripts/verify/m026-p02-phase-suite.sh`

### Artifacts

- `scripts/verify/m026-p02-edition-detection-contract.sh` (min 40 lines, contains "edition=")
- `scripts/verify/m026-p02-adapter-invariants.sh` (min 40 lines, contains "CONVERSUS_")
- `scripts/verify/m026-p02-jsonl-edition-field.sh` (min 30 lines, contains "edition")
- `scripts/verify/m026-p02-dual-edition-test-shape.sh` (min 30 lines, contains "CONVERSUS_INTEGRATION")
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` (min 40 lines, contains "arbiter")
- `scripts/verify/m026-p02-recent-changes.sh` (min 25 lines, contains "M026/P02")
- `scripts/verify/m026-p02-phase-suite.sh` (min 50 lines, contains "SUMMARY: m026-p02-phase-suite.sh")

### Key Links

- `scripts/dispatch/adapters/tool/conversus.sh` → `references/architecture.md` (header comment must point at the "Conversus Adapter — Operator Notes" section added in M026/P01's post-verify commit 32ab6ea)
- `CLAUDE.md` → `.orchestrator/milestones/M026/phases/P02/P02-SUMMARY.md` (Recent Changes fragment names the P02 summary)
- `AGENTS.md` → `.orchestrator/milestones/M026/phases/P02/P02-SUMMARY.md` (dual-write parity)

## Tasks

### T01: Adapter edition-detection resolver (FR-1 / FR-2 / FR-3 / CON-1..CON-3)

See `tasks/T01-PLAN.md`.

### T02: JSONL `edition` field (FR-4 / AD-4)

See `tasks/T02-PLAN.md`.

### T03: Dual-edition regression test (FR-8 / SC-4 / SC-6 / DC-4)

See `tasks/T03-PLAN.md`.

### T04: Gate-verdict reliability bundle — POST-P01 F1/F2/F3, closes OQ-16

See `tasks/T04-PLAN.md`.

### T05: Phase verification suite + Recent Changes dual-write

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 (resolver) → T02 (JSONL) → T03 (dual-edition test) → T04 (reliability) → T05 (phase-suite + RC)
```

Linear chain. T02/T03/T04 each build on T01's resolver output. T04 additionally modifies `conversus.sh` (shared file with T01), so must run after T02/T03 to avoid merge-path complexity. T05 orchestrates verification across all prior tasks and must run last.

Parallelism opportunity: T02 and T03 could run in parallel — T02 modifies `github-common.sh` + `specify.sh`; T03 modifies `tests/test-conversus-adapter-shim.sh`. Neither touches `conversus.sh`. Kept linear for simplicity; dispatch may re-order if operator opts into parallelism.

## Files Likely Touched

- `scripts/dispatch/adapters/tool/conversus.sh` (modify — T01, T04)
- `scripts/integrations/github-common.sh` (modify — T02)
- `scripts/specify/specify.sh` (modify — T02)
- `tests/test-conversus-adapter-shim.sh` (modify — T03)
- `scripts/verify/m026-p02-edition-detection-contract.sh` (create — T01)
- `scripts/verify/m026-p02-adapter-invariants.sh` (create — T01)
- `scripts/verify/m026-p02-jsonl-edition-field.sh` (create — T02)
- `scripts/verify/m026-p02-dual-edition-test-shape.sh` (create — T03)
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` (create — T04)
- `scripts/verify/m026-p02-recent-changes.sh` (create — T05)
- `scripts/verify/m026-p02-phase-suite.sh` (create — T05)
- `CLAUDE.md` (modify — T05 via dual-write helper)
- `AGENTS.md` (modify — T05 via dual-write helper)

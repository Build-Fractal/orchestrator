---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M028"
goal: "Hook portability + adapter+installer dedup (Findings A + F folded) — make the PreToolUse shape-guard hook fire from a runtime-stable install location in any consumer project, fix the runtime adapter to emit absolute `bash <hooks-dir>/<name>.sh` invocations every entry tagged `_orchestrator_managed: true`, give `settings-merge.sh` install-side dedup keyed on (event, matcher, command) × that tag, extend the Claude Code installer to copy the hook + classifier + reject_lookup payload + both lifecycle scripts into `~/.claude/orchestrator-hooks/`, add a `--repair` flag (with `--dry-run` preview) that removes flag-less M025 orphans by exact-tuple match, and gate the whole surface with a pinned-sha install-roundtrip byte-equality verifier plus per-finding A/F verifiers."
demo_sentence: "A developer in any consumer project runs `bash packaging/install/install-claude-code.sh` against a fresh `~/.claude/settings.json`; the runtime-stable hooks dir lands at `~/.claude/orchestrator-hooks/` containing `pre-bash-shape-guard.sh`, `shape-classifier.sh`, the reject_lookup, `before-commit.sh`, and `after-verify-sync.sh`; rerunning the installer produces a byte-identical `~/.claude/settings.json`; running it once more with `--uninstall` returns the file to its pre-install canonical bytes; `bash scripts/verify/m028/install-roundtrip.sh`, `bash scripts/verify/m028/finding-A-verifier.sh`, and `bash scripts/verify/m028/finding-F-verifier.sh` all exit 0."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`. Verified by inspecting the hook body for the literal `BASH_SOURCE` self-location pattern and the absence of any `CLAUDE_PROJECT_DIR` reference inside the resolution block. Satisfies FR-2 + US-1 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-hook-self-locate.sh`

- The Claude Code runtime adapter emits, for every hook entry, a `command` field of the literal shape `bash <hooks-dir>/<name>.sh` (never a bare command name) and every emitted leaf object carries `_orchestrator_managed: true`. Verified by capturing `--hook-config` output and asserting each `command` field starts with `bash ` and ends with `.sh`, and that the count of `_orchestrator_managed: true` flags equals the count of leaf hook objects. Satisfies FR-3 + FR-4 + US-1 + US-3 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/p02-adapter-absolute-paths.sh`

- The shape-guard hook self-conforms to its own classifier output under AP-009 (no compound chain exceeding 2 connectors anywhere in its body). Verified by sourcing the [M021](../../../../milestones/M021/index.md) classifier, scanning the hook body line-by-line, and asserting `classify_command` returns ALLOW for every non-comment non-blank line. Satisfies CON-3 + FR-21 (P02 half — P03's `finding-G-self-conformance.sh` verifies via the M028 classifier; P02 verifier here uses M021 classifier as the day-one floor).
  - Check: `bash scripts/verify/m028/p02-hook-self-conformance.sh`

- `settings-merge.sh merge` is install-side idempotent — running the install path twice in succession against the same target settings.json produces a byte-identical file (SHA-256 equal). The dedup key is `(event, matcher, command) × _orchestrator_managed: true`. Verified by the install-roundtrip pinned-sha gate.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --uninstall` against a post-install state returns `~/.claude/settings.json` to its pre-install canonical bytes ([M025](../../../../milestones/M025/index.md) reversibility extended to M028's expanded entry set). Verified by the install-roundtrip pinned-sha gate's reversibility leg.
  - Check: `bash scripts/verify/m028/install-roundtrip.sh`

- `bash packaging/install/install-claude-code.sh --repair` (and the `--repair --dry-run` preview) removes flag-less orphan entries whose `(event, matcher, command)` tuple matches a known M025 pattern fingerprint (exact-tuple match, never structural-shape match) and preserves user-authored entries verbatim. Verified by running the repair path against the canonical pre-repair fixture P01/T02 produced and asserting the result matches a canonical post-repair reference.
  - Check: `bash scripts/verify/m028/p02-repair-fixture.sh`

- The installer copies the full hooks payload (`pre-bash-shape-guard.sh`, `shape-classifier.sh`, the reject_lookup data, `before-commit.sh`, `after-verify-sync.sh`) into `~/.claude/orchestrator-hooks/` on a fresh install. Verified by running the installer against an isolated `HOME` fixture and asserting every expected file is present at the expected path. Satisfies FR-1.
  - Check: `bash scripts/verify/m028/p02-hooks-payload-staged.sh`

- The Finding A end-to-end verifier passes: in a fresh consumer-project context where `$CLAUDE_PROJECT_DIR` does NOT point at the orchestrator repo, the installed hook locates its classifier successfully and rejects a verbatim Finding A screenshot command. Satisfies US-1 acceptance scenarios 1 + 4.
  - Check: `bash scripts/verify/m028/finding-A-verifier.sh`

- The Finding F end-to-end verifier passes: a fresh-install fixture's Stop event resolves `bash <hooks-dir>/after-verify-sync.sh`, the script executes successfully, and no `command not found` diagnostic surfaces. Satisfies SC-5 + US-3 acceptance scenario 4.
  - Check: `bash scripts/verify/m028/finding-F-verifier.sh`

### Artifacts

- `scripts/hooks/pre-bash-shape-guard.sh` (min 80 lines, contains "BASH_SOURCE")
- `scripts/dispatch/adapters/runtime/claude-code.sh` (min 200 lines, contains "orchestrator-hooks")
- `scripts/util/settings-merge.sh` (min 200 lines, contains "_orchestrator_managed")
- `packaging/install/install-claude-code.sh` (min 350 lines, contains "--repair")
- `scripts/verify/m028/install-roundtrip.sh` (min 30 lines, contains "shasum")
- `scripts/verify/m028/finding-A-verifier.sh` (min 20 lines, contains "BASH_SOURCE")
- `scripts/verify/m028/finding-F-verifier.sh` (min 20 lines, contains "after-verify-sync")
- `scripts/verify/m028/p02-hook-self-locate.sh` (min 10 lines, contains "BASH_SOURCE")
- `scripts/verify/m028/p02-hook-self-conformance.sh` (min 10 lines, contains "AP-009")
- `scripts/verify/m028/p02-adapter-absolute-paths.sh` (min 10 lines, contains "_orchestrator_managed")
- `scripts/verify/m028/p02-hooks-payload-staged.sh` (min 10 lines, contains "orchestrator-hooks")
- `scripts/verify/m028/p02-repair-fixture.sh` (min 10 lines, contains "m028-pre-repair-snapshot")
- `tests/fixtures/m028-post-repair-canonical.json` (min 5 lines, contains "_orchestrator_managed")

### Key Links

- `scripts/verify/m028/install-roundtrip.sh` → `packaging/install/install-claude-code.sh` (round-trip gate invokes the installer)
- `scripts/verify/m028/finding-A-verifier.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (verifier exercises the self-locating hook)
- `scripts/verify/m028/finding-F-verifier.sh` → `scripts/lifecycle/after-verify-sync.sh` (verifier exercises the resolved Stop-hook script)
- `scripts/verify/m028/p02-repair-fixture.sh` → `tests/fixtures/m028-pre-repair-snapshot.json` (repair verifier consumes the P01/T02 canonical pre-repair fixture)
- `packaging/install/install-claude-code.sh` → `scripts/util/settings-merge.sh` (installer delegates merge + dedup)
- `packaging/install/install-claude-code.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (installer copies the hook into the runtime-stable hooks dir)

## Tasks

### T01: Hook self-location via BASH_SOURCE (Finding A core)

See `tasks/T01-hook-self-locate-PLAN.md`.

### T02: Runtime adapter absolute-path emission + every-entry _orchestrator_managed flag (Finding F adapter half)

See `tasks/T02-adapter-absolute-paths-PLAN.md`.

### T03: Installer payload copy + settings-merge install-side dedup (Findings A + F installer half + FR-1, FR-4, FR-5)

See `tasks/T03-installer-payload-and-dedup-PLAN.md`.

### T04: --repair flag with --dry-run preview (FR-7)

See `tasks/T04-repair-flag-PLAN.md`.

### T05: Install-roundtrip pinned-sha gate + per-finding A/F verifiers (FR-6 + SC-2 + SC-5 + SC-7)

See `tasks/T05-roundtrip-and-verifiers-PLAN.md`.

## Task Dependencies

```
T01 ─→ T03 ─→ T04 ─→ T05
T02 ─→ T03
```

T01 and T02 are independent (different files, different concerns — hook self-location vs adapter emission). Both must complete before T03, because T03's installer copies the modified hook into the runtime-stable dir and consumes the modified adapter's `--hook-config` output as the merge fragment. T04 extends the same installer file as T03 (`packaging/install/install-claude-code.sh`); the edits are serialized by file convention to avoid merge interference. T05 depends on every prior task because the install-roundtrip gate exercises the full installed surface and the per-finding verifiers exercise the hook + adapter + installer end-to-end.

## Files Likely Touched

- `scripts/hooks/pre-bash-shape-guard.sh` (modify)
- `scripts/dispatch/adapters/runtime/claude-code.sh` (modify)
- `scripts/util/settings-merge.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `scripts/verify/m028/install-roundtrip.sh` (create)
- `scripts/verify/m028/finding-A-verifier.sh` (create)
- `scripts/verify/m028/finding-F-verifier.sh` (create)
- `scripts/verify/m028/p02-hook-self-locate.sh` (create)
- `scripts/verify/m028/p02-hook-self-conformance.sh` (create)
- `scripts/verify/m028/p02-adapter-absolute-paths.sh` (create)
- `scripts/verify/m028/p02-hooks-payload-staged.sh` (create)
- `scripts/verify/m028/p02-repair-fixture.sh` (create)
- `tests/fixtures/m028-post-repair-canonical.json` (create)

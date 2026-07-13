---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M046"
goal: "Productionize the P01 default-DENY PreToolUse probe into a framework-owned, bundle-installed unattended scope-guard hook that constrains BOTH write paths (allowlist + FR-20 read-only protected surface) AND the tool surface (deny network Bash, git push, rm outside scope, and all MCP unless allowlisted), env-gated to the unattended child only, plus milestone-blocking non-stubbed SC-5 (write/Bash/MCP scope) and SC-15 (verification-integrity) harnesses"
demo_sentence: "A real unattended child (ORCHESTRATOR_UNATTENDED=1, the live production hook installed via the M028 path) is BLOCKED (exit 2) when it attempts an out-of-scope write, an out-of-scope Bash `git push`, an MCP tool call outside the allowlist, or an edit to its own success criteria / verification harness / scoring record — while the operator's own interactive session (no env var) and the attended path are entirely unconstrained, and an in-scope work-dir write passes."
risk: "high"
depends_on: [P01, P04]
---

## Phase Overview

P05 turns the P01 throwaway default-DENY PreToolUse probe
(`.orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh`,
which proved deny-unless-allowlisted works through the real stdin→exit-2 hook
contract and rides the M028 consumer install path on both install shapes) into
the **production** hook that ships in the install bundle and enforces FR-9 +
FR-20/CON-7. Nothing in `auto-loop.sh` is touched (CON-2). The attended path and
the operator's interactive session stay byte-unaffected (the safety-critical
correctness point below).

**Activation model — env-gated, default-OFF (Decision D017, recorded at plan
time).** The production hook `scripts/hooks/unattended-scope-guard.sh` is wired
permanently into `~/.claude/settings.json` (matcher `Write|Edit|Bash|mcp__.*`)
by the M028 install path, but its FIRST action is
`if [ -z "${ORCHESTRATOR_UNATTENDED:-}" ]; then exit 0; fi` — a no-op that
returns pass for EVERY tool call whenever the unattended flag is absent from the
environment. The M046 driver already exports `ORCHESTRATOR_UNATTENDED=1` into the
spawned child (`scripts/lifecycle/self-continue-drive.sh` `run_child`, line 145),
so enforcement is scoped precisely to the unattended child. The operator's own
`claude` session never sets that env var, so the hook is inert there. **This is
the load-bearing safety property of the whole phase: a permanently-installed
default-DENY hook must never constrain interactive work.** SC-5's env-gate leg
proves the no-op.

**Policy source — committed manifest + per-run driver composition (Decision
D018).** The read-only protected surface (FR-20) is a framework-generic,
committed, bundled manifest `scripts/hooks/unattended-protected-surface.txt`
(project-relative globs: `specs/`, `tools/verify/`, `scripts/verify/`,
`scripts/hooks/`). The *writable* allowlist is only knowable at spawn time (it is
the active project root), so the driver COMPOSES a per-run policy file
`<milestone-dir>/.self-continue-scope-policy` before each spawn — absolute
`allow_path <project-root>/` + the manifest's globs abs-resolved to
`readonly_path` + the milestone-specific SC surfaces (the roadmap, the active
phase plan, the P07 attempts-ledger forward-slot, and the policy file itself so
the child cannot widen its own allowlist) + no `allow_tool` line (⇒ MCP
default-deny) — then exports `ORCHESTRATOR_UNATTENDED_POLICY=<path>` into the
child. The hook reads that env var and fails closed (deny-all except read-class)
when it is unset/unreadable under `ORCHESTRATOR_UNATTENDED`. This mirrors the P01
probe's `DENY_PROBE_POLICY` allow_path/allow_tool/allow_bash format, extended
with a `readonly_path` directive.

**MCP deny model — default-DENY all `mcp__*` unless allowlisted (Decision
D019).** Exactly the P01 probe's proven `mcp__*` branch: an `mcp__*` tool call is
denied unless an exact `allow_tool <name>` directive names it; the empty default
allowlist denies every MCP call. This is inside the milestone-blocking SC-5 gate
(the MCP vector is the primary danger worktree filesystem isolation cannot
contain — Problem Statement Gap 2).

**FR-20 read-only semantics — the doing-vs-scoring seam (recorded here,
Design-Before-Code).** For a path under a `readonly_path` prefix the hook denies
`Edit`/`NotebookEdit` unconditionally (mutation of an existing scoring surface)
and denies `Write` when the target file already EXISTS (overwrite = gaming), but
passes `Write` to a not-yet-existing path through to the normal allow check. This
single rule resolves the tension the payload named: the child may CREATE a brand-
new per-phase verifier under `tools/verify/` (legitimate doing) but may never
MODIFY or OVERWRITE the existing verification harness, SC definitions, or scoring
records that gate its own completion (CON-7). SC-15 proves all three protected
categories deny an EDIT.

**Consumes (on disk, from P01/P02/P04 — all complete):**
`scripts/lifecycle/self-continue-drive.sh` (P02/P04 hardened driver; exports
`ORCHESTRATOR_UNATTENDED=1` into the child at line 145; note `REPO_ROOT` inside
this script resolves to `<repo>/scripts`, so the project root is
`"$REPO_ROOT/.."` and the manifest is `"$REPO_ROOT/hooks/..."`),
`scripts/lifecycle/unattended-envelope.sh` (P04 sourceable function library — the
seam where the policy-composition function lands to keep the driver diff small,
per the P04 precedent), `scripts/util/settings-merge.sh` (M025/M028 merge helper),
`packaging/install/install-claude-code.sh` (`HOOKS_PAYLOAD` staging + settings
merge), `scripts/dispatch/adapters/runtime/claude-code.sh` (`--hook-config`
fragment emitter), the P01 probe + fixtures + `drive-hook-case.sh` +
`run-install-matrix.sh` (patterns the SC-5 harness extends), the four bundle
install shapes proven by P01 (`m046-p01-install-matrix.sh`).

## Must-Haves

### Truths

- The production hook no-ops (exit 0) for every tool call when `ORCHESTRATOR_UNATTENDED` is unset — the operator's interactive session is never constrained.
  - Check: `bash tools/verify/m046-p05-scope-guard-deny.sh`
- Under `ORCHESTRATOR_UNATTENDED=1` with a policy, the hook denies (exit 2) an out-of-scope Write, a `git push` Bash, a network Bash (curl), an `rm` outside scope, and any `mcp__*` call not in `allow_tool`; and passes read-class tools, an in-`allow_path` Write, and an `allow_bash`-matched command.
  - Check: `bash tools/verify/m046-p05-scope-guard-deny.sh`
- Under `readonly_path`, the hook denies Edit/NotebookEdit unconditionally and denies Write to an already-existing protected file, but passes Write to a not-yet-existing path (create-new preserved).
  - Check: `bash tools/verify/m046-p05-scope-guard-deny.sh`
- The production hook + manifest ride the M028 install path (added to `HOOKS_PAYLOAD` + a new `Write|Edit|Bash|mcp__.*` matcher wrapper in `--hook-config`) and install cleanly into an isolated HOME on both shapes (source + bundle), coexisting with `pre-bash-shape-guard.sh`, idempotent on re-merge, uninstall-clean.
  - Check: `bash tools/verify/m046-p05-install-wiring.sh`
- Under `--unattended` the driver composes a per-run `.self-continue-scope-policy` (absolute `allow_path <project-root>/`, `readonly_path` lines from the committed manifest + the roadmap + active phase plan + policy file, no `allow_tool` ⇒ MCP deny) and exports `ORCHESTRATOR_UNATTENDED_POLICY` into the child; the attended path composes no policy and exports no such var.
  - Check: `bash tools/verify/m046-p05-driver-policy.sh`
- SC-5 (NON-STUBBED, milestone-blocking): a real unattended child driven through the LIVE installed production hook is BLOCKED (exit 2) on (a) an out-of-scope write, (b) an out-of-scope `git push`, AND (c) an out-of-scope `mcp__*` tool call; the env-gate leg (no `ORCHESTRATOR_UNATTENDED`) passes all three; positive controls pass.
  - Check: `bash tools/verify/m046-p05-sc5-write-tool-scope.sh`
- SC-15 (NON-STUBBED, milestone-blocking): a real unattended child editing an SC definition, the verification harness, OR its own scoring record is BLOCKED (exit 2) by the live hook, while a legitimate work-dir summary Write passes (protected surface is scoped, not a blanket milestone-dir deny).
  - Check: `bash tools/verify/m046-p05-sc15-verification-immutability.sh`
- The phase suite aggregates all five P05 verifiers and reports 5/5 pass.
  - Check: `bash tools/verify/m046-p05-phase-suite.sh`

### Artifacts

- scripts/hooks/unattended-scope-guard.sh (min 130 lines, contains "ORCHESTRATOR_UNATTENDED")
- scripts/hooks/unattended-protected-surface.txt (min 12 lines, contains "readonly_path")
- tools/verify/m046-p05-scope-guard-deny.sh (min 60 lines, contains "ORCHESTRATOR_UNATTENDED")
- tools/verify/m046-p05-install-wiring.sh (min 60 lines, contains "mcp__")
- tools/verify/m046-p05-driver-policy.sh (min 40 lines, contains "ORCHESTRATOR_UNATTENDED_POLICY")
- tools/verify/m046-p05-sc5-write-tool-scope.sh (min 70 lines, contains "oos-mcp")
- tools/verify/m046-p05-sc15-verification-immutability.sh (min 60 lines, contains "readonly_path")
- tools/verify/m046-p05-phase-suite.sh (min 40 lines, contains "SUMMARY:")

### Key Links

- packaging/install/install-claude-code.sh → scripts/hooks/unattended-scope-guard.sh (HOOKS_PAYLOAD staging line)
- scripts/dispatch/adapters/runtime/claude-code.sh → unattended-scope-guard.sh (Write|Edit|Bash|mcp__.* matcher wrapper)
- scripts/lifecycle/unattended-envelope.sh → unattended-protected-surface.txt (policy-composition reads the committed manifest)
- tools/verify/m046-p05-phase-suite.sh → m046-p05-scope-guard-deny.sh (suite member invocation)

## Tasks

### T01: Production scope-guard hook + protected-surface manifest + unit verifier

Create the framework-owned `scripts/hooks/unattended-scope-guard.sh` (productionizes the P01
probe: env-gate no-op unless `ORCHESTRATOR_UNATTENDED`; policy from
`ORCHESTRATOR_UNATTENDED_POLICY`; default-DENY MCP; `readonly_path` deny-edit/deny-overwrite
+ `allow_path` write scope; Bash deny git-push/network/rm-outside-scope with `allow_bash`
override; read-class always pass; fail-closed on missing policy) and the committed generic
manifest `scripts/hooks/unattended-protected-surface.txt` (`readonly_path` globs + documented
P07 ledger forward-slot). Author `tools/verify/m046-p05-scope-guard-deny.sh` driving the full
policy matrix (incl. the env-gate no-op leg) against fixtures via the real stdin→exit-2
contract. See `tasks/T01-scope-guard-hook-PLAN.md`.

### T02: M028 install-path wiring (HOOKS_PAYLOAD + adapter matcher) + install verifier

Modify `packaging/install/install-claude-code.sh` to add the hook + manifest to
`HOOKS_PAYLOAD`, and `scripts/dispatch/adapters/runtime/claude-code.sh` to emit a new
`PreToolUse` wrapper `matcher "Write|Edit|Bash|mcp__.*"` → `bash ${HOME_HOOKS}/unattended-scope-guard.sh`
(`_orchestrator_managed: true`), coexisting with the existing `Bash` matcher wrapper. Author
`tools/verify/m046-p05-install-wiring.sh` (productionizes P01's `run-install-matrix.sh`: real
installer into isolated HOME on shapes A + B; staged+executable; matcher merged; `mcp__.*`
coexists with shape-guard; idempotent; uninstall-clean). See `tasks/T02-install-wiring-PLAN.md`.

### T03: Driver per-run policy composition + env export

Add `envelope_write_scope_policy` to `scripts/lifecycle/unattended-envelope.sh` (composes the
absolute `allow_path`/`readonly_path`/MCP-deny policy from the committed manifest + project
root + milestone SC surfaces, atomic temp+rename) and wire `scripts/lifecycle/self-continue-drive.sh`
to call it in the pre-spawn block under `UNATTENDED=true` and export
`ORCHESTRATOR_UNATTENDED_POLICY` into `run_child` alongside `ORCHESTRATOR_UNATTENDED=1`; the
attended path is untouched. Author `tools/verify/m046-p05-driver-policy.sh`. See
`tasks/T03-driver-policy-PLAN.md`.

### T04: SC-5 live non-stubbed write/Bash/MCP scope harness (milestone-blocking)

Author `tools/verify/m046-p05-sc5-write-tool-scope.sh`: isolated scratch HOME, run the REAL
installer (production hook wired into that HOME's `settings.json`), compose a per-run policy via
the T03 driver function, resolve the LIVE installed hook from `settings.json`, and drive it
through the real stdin→exit-2 contract with `ORCHESTRATOR_UNATTENDED=1` for oos-write / oos-bash-
gitpush / oos-mcp (all DENY), plus the env-gate leg (all PASS) and positive controls. See
`tasks/T04-sc5-write-tool-scope-PLAN.md`.

### T05: SC-15 live non-stubbed verification-integrity harness (milestone-blocking)

Author `tools/verify/m046-p05-sc15-verification-immutability.sh`: same isolated-HOME live-hook
drive; DENY an Edit of an SC definition (`specs/.../spec.md`), an Edit of an existing verification
harness file (`tools/verify/m046-*.sh`), and a Write/Edit of the child's scoring record (the P07
ledger forward-slot / execution-log scoring record); PASS a legitimate work-dir summary Write.
See `tasks/T05-sc15-verification-immutability-PLAN.md`.

### T06: Phase-suite aggregator

Author `tools/verify/m046-p05-phase-suite.sh` aggregating the five P05 verifiers (SUITE line per
member + SUMMARY; exit 0 iff 5/5), modeled on `tools/verify/m046-p04-phase-suite.sh`. See
`tasks/T06-phase-suite-PLAN.md`.

## Task Dependencies

T01 → T02 → T03
T03 → T04
T03 → T05   (T04 and T05 can run in parallel after T03)
T04 + T05 → T06

## Boundary Map

- T01 Produces: `scripts/hooks/unattended-scope-guard.sh` (env-gate no-op; policy directives allow_path/readonly_path/allow_tool/allow_bash; MCP default-deny; readonly deny-edit + deny-overwrite; Bash dangerous-class deny; fail-closed); `scripts/hooks/unattended-protected-surface.txt`; `tools/verify/m046-p05-scope-guard-deny.sh` + `tools/verify/fixtures/m046-p05/*.json`. Consumes: P01 probe semantics (`unattended-deny-probe.sh`) + fixture/drive patterns.
- T02 Produces: `HOOKS_PAYLOAD`-extended `packaging/install/install-claude-code.sh`; `--hook-config`-extended `scripts/dispatch/adapters/runtime/claude-code.sh`; `tools/verify/m046-p05-install-wiring.sh`. Consumes: T01 hook + manifest; `scripts/util/settings-merge.sh`; P01 `run-install-matrix.sh` pattern.
- T03 Produces: `envelope_write_scope_policy` in `scripts/lifecycle/unattended-envelope.sh`; policy-composing `scripts/lifecycle/self-continue-drive.sh` (`ORCHESTRATOR_UNATTENDED_POLICY` export); `tools/verify/m046-p05-driver-policy.sh`. Consumes: T01 manifest; P04 driver/envelope surface.
- T04 Produces: `tools/verify/m046-p05-sc5-write-tool-scope.sh` (SC-5). Consumes: T02 install wiring; T03 policy composition; T01 hook.
- T05 Produces: `tools/verify/m046-p05-sc15-verification-immutability.sh` (SC-15). Consumes: T02 install wiring; T03 policy composition; T01 manifest readonly globs.
- T06 Produces: `tools/verify/m046-p05-phase-suite.sh`. Consumes: T01–T05 verifier set.

## Plan-Time Discipline Record

1. **Prerequisite existence** — verified on disk at plan-authoring time:
   `.orchestrator/milestones/M046/phases/P01/spike/hook/unattended-deny-probe.sh` (206 lines),
   `.../spike/hook/drive-hook-case.sh`, `.../spike/hook/run-install-matrix.sh`,
   `scripts/lifecycle/self-continue-drive.sh` (exports `ORCHESTRATOR_UNATTENDED=1` at line 145;
   sources `unattended-envelope.sh` at line 172; `REPO_ROOT=<repo>/scripts` at line 165),
   `scripts/lifecycle/unattended-envelope.sh` (P04 library), `scripts/util/settings-merge.sh`
   (merge/uninstall/repair), `packaging/install/install-claude-code.sh` (`HOOKS_PAYLOAD` at
   lines 403–407; settings merge at 442–474), `scripts/dispatch/adapters/runtime/claude-code.sh`
   (`--hook-config` heredoc at lines 198–219; existing `PreToolUse`/`Bash` wrapper at 208–216),
   `scripts/hooks/pre-bash-shape-guard.sh`, `tools/verify/m046-p04-phase-suite.sh` (aggregator
   template). All present.
2. **Verifier availability** — every `## Verification` command in every task plan is authored
   inside that same task's Steps (each `m046-p05-*.sh` verifier is a deliverable of the task
   whose Truth cites it); T06's phase-suite cites T01–T05 members, all authored earlier in
   dependency order. No forward references to unwritten verifiers.
3. **Classifier pre-validation** — `bash scripts/util/classify-command.sh "bash tools/verify/m046-p05-scope-guard-deny.sh"` → `AUTO_SAFE`;
   `... "bash tools/verify/m046-p05-sc5-write-tool-scope.sh"` → `AUTO_SAFE`;
   `... "bash tools/verify/m046-p05-phase-suite.sh"` → `AUTO_SAFE` (all three recorded live at
   plan time; every Check: shares the single-script shape). The hook file itself and the driver
   policy-write introduce NO lines that appear in any `## Verification` block (they are exercised
   only inside verifier scripts, which use `mktemp` scratch internally), so no shape-guard input
   trace is required for them.
4. **run-probe scope** — all verifiers are repo-resident under `tools/verify/` and invoked
   directly (`bash tools/verify/...`); `run-probe.sh` is not used. The SC-5/SC-15 harnesses stage
   their isolated HOMEs under `mktemp -d`/`/private/tmp` internally (P01 precedent) — never wired
   into the real `~/.claude`.
5. **Real-DB rule** — N/A: no SQL, schema, or DB-bound code in this phase.
6. **Path-collision check** — `ls` performed at plan time: no `scripts/hooks/unattended-scope-guard.sh`,
   no `scripts/hooks/unattended-protected-surface.txt`, no `tools/verify/m046-p05-*` (tools/verify
   tops out at `m046-p04-*`), no `.orchestrator/milestones/M046/phases/P05/tasks/` yet. All CREATE
   paths are absent. `install-claude-code.sh`, `claude-code.sh`, `self-continue-drive.sh`,
   `unattended-envelope.sh` are declared MODIFY, not create. Isolated-HOME scratch dirs and the
   per-run `.self-continue-scope-policy` dotfile are generated in `mktemp`/milestone scratch at
   runtime, not committed.

## Safety Constraints (binding on every harness task)

- **Isolated scratch HOME, always.** T02/T04/T05 run the real installer and/or wire a deny-hook
  into a `settings.json`. Every one MUST use an isolated scratch `HOME` (P01/T01 precedent:
  `HOME="$scratch" bash .../install-claude-code.sh`). The operator's real `~/.claude` MUST NEVER
  be touched. A harness that writes to `$HOME/.claude` without first overriding `HOME` is a
  defect and MUST fail its own self-check.
- **CON-2**: `auto-loop.sh` is not modified anywhere in this phase.
- **FR-17 attended parity**: the driver's attended path (no `--unattended`) MUST compose no
  policy, export no `ORCHESTRATOR_UNATTENDED_POLICY`, and remain byte-compatible with the P04
  driver; T03's verifier asserts this.

## Files Likely Touched

- scripts/hooks/unattended-scope-guard.sh (create)
- scripts/hooks/unattended-protected-surface.txt (create)
- scripts/lifecycle/unattended-envelope.sh (modify)
- scripts/lifecycle/self-continue-drive.sh (modify)
- packaging/install/install-claude-code.sh (modify)
- scripts/dispatch/adapters/runtime/claude-code.sh (modify)
- tools/verify/m046-p05-scope-guard-deny.sh (create)
- tools/verify/m046-p05-install-wiring.sh (create)
- tools/verify/m046-p05-driver-policy.sh (create)
- tools/verify/m046-p05-sc5-write-tool-scope.sh (create)
- tools/verify/m046-p05-sc15-verification-immutability.sh (create)
- tools/verify/m046-p05-phase-suite.sh (create)
- tools/verify/fixtures/m046-p05/ (create; hook-drive fixture payloads)

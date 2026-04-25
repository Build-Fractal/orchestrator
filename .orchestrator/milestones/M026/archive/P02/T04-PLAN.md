---
schema_version: "1.0"
task: "T04"
phase: "P02"
milestone: "M026"
name: "Gate-verdict reliability bundle — POST-P01-FINDINGS F1 complete + F2 + F3; closes OQ-16"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: `_resolve_edition` + `_resolve_binary` updates are live in `scripts/dispatch/adapters/tool/conversus.sh`.
- T02 complete: JSONL emitters include `edition`.
- T03 complete: dual-edition test covers SC-4 / SC-6.
- **POST-P01-FINDINGS.md** (`.orchestrator/milestones/M026/phases/P01/POST-P01-FINDINGS.md`) is authoritative for F1/F2/F3 scope. Read it in full before starting — this task closes findings F1, F2, and F3 together.
- **Post-verify commit `32ab6ea`** already made a partial F1 fix: rationale is synthesized from `verdict + surviving_disputes + mode` rather than copying the linter's misleading `summary` string. This task completes F1 by preferring the arbiter/synthesis **verdict-text** extraction when available, falling back to the 32ab6ea synthesized formula when not.
- **DOGFOOD-SMOKE-OSS.md §6** (`.orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md`) is the empirical grounding: false-PASS on `CONVERSUS_PROVIDER=claude-code` is reproducible on OSS (5-phase deliberation ran, prose synthesis output, parser returned 0 disputes, adapter reported PASS while the synthesis said BLOCK/8).
- **Spec 027 OQ-16** (`specs/027-conversus-oss-migration/spec.md`) documents the choice between upstream-fix / adapter-layer-fix / document-only. This task implements **option 2** (adapter-layer provider-aware verdict derivation) plus a subset of option 3 (documented fallback), not option 1 (upstream fix is out of M026 scope per CON-5).
- `references/architecture.md` "Conversus Adapter — Operator Notes" section exists (commit `32ab6ea`) and documents the CONVERSUS_PROVIDER=claude-code rule as operator discipline. F3 promotes that rule to an auto-preflight.

## Description

Three tightly-coupled adapter-layer changes that restore gate-verdict trustworthiness on the `CONVERSUS_PROVIDER=claude-code` path and improve gate-result readability across all provider paths.

### F1 (complete): Rationale extraction from verdict text

Current state post-`32ab6ea`: rationale is `verdict=<V> derived from surviving_disputes=<N> in <mode> deliberation`. That reads true but thin.

F1 target: when the synthesis file contains a `## Verdict` section (which the Risk Register format emits), extract its first paragraph (one line, newlines collapsed) and use that as the rationale. Fall back to the 32ab6ea formula when the section is absent or extraction yields an empty string.

### F2: Prefer `arbiter/resolution.md` when present

Current state: adapter reads only `${_run_output_dir}/summary/final.md` at line 301.

F2 target: if `${_run_output_dir}/arbiter/resolution.md` exists, prefer it as the verdict-text source for the F1 rationale extraction. Keep `summary/final.md` as the source for the structural fields the arbiter file doesn't emit (`headline`, the `quality_indicators.genuine_disagreements_surviving` count used by the existing `linter.output_contract` invocation). Schema: **prefer arbiter verdict-text, supplement with synthesis structural fields.**

### F3: Auto-preflight `CONVERSUS_PROVIDER=claude-code` under OAuth

Current state: the architecture.md "Conversus Adapter — Operator Notes" section tells operators to set `CONVERSUS_PROVIDER=claude-code` manually when authenticated via Anthropic OAuth. Forgetting costs ~90 minutes of 429 debugging (per POST-P01-FINDINGS F3).

F3 target: before the adapter resolves `_provider` at line ~288 in the `gate` subcommand, check if the operator is on OAuth auth. Detection: (a) `ANTHROPIC_API_KEY` is NOT exported in the environment AND (b) `~/.conversus/auth.json` exists with a record indicating subscription/OAuth auth. If both hold AND `CONVERSUS_PROVIDER` is unset, emit a single-line stderr warning and set `CONVERSUS_PROVIDER=claude-code` for the duration of this invocation. Honor the operator's explicit setting — if `CONVERSUS_PROVIDER` is already set to anything (including empty string explicitly), do not override.

Detection for `~/.conversus/auth.json` shape:
- If the file does not exist: treat as API-key mode (no action).
- If the file exists: read it as JSON if `python3` is available; look for a provider entry with keys like `oauth`, `subscription`, or `access_token` (exact schema inspection requires reading the OSS `engine/auth.py` at `~/Sites/conversus-oss/engine/auth.py` — CON-5 allows read-only). Heuristic fallback: `grep -q '"oauth"\|"subscription"\|access_token' ~/.conversus/auth.json` treats presence as OAuth. If `python3` is not available AND the grep fallback fails, do not auto-preflight (degrade gracefully; operator can still set the env var manually).

## Steps

1. **Read the OSS `engine/auth.py`** (read-only per CON-5) to confirm the auth.json record shape:
   ```
   head -120 ~/Sites/conversus-oss/engine/auth.py
   ```
   Identify the exact key (likely `auth_method`, `credential_type`, or a nested field) that distinguishes OAuth from API-key. Encode the discovered key into F3's detection. If the shape is ambiguous, fall back to the grep heuristic above.
2. **F1 + F2 in `scripts/dispatch/adapters/tool/conversus.sh`** (current rationale block at lines ~355-367):
   - Immediately before the existing `_mode_label="${_mode:-cooperative}"` / `_rationale="verdict=..."` block, attempt to extract a verdict-text rationale:
     ```sh
     _rationale_text=""
     # F2: prefer arbiter/resolution.md when present.
     _arbiter_file="${_run_output_dir}/arbiter/resolution.md"
     if [ -f "$_arbiter_file" ]; then
       _verdict_source="$_arbiter_file"
     else
       _verdict_source="$_synthesis"
     fi
     # F1 complete: extract first paragraph of the `## Verdict` section.
     # Uses awk to locate the section heading and print lines until the next
     # heading or blank line. Collapses newlines to spaces for frontmatter safety.
     _rationale_text="$(awk '
       /^## Verdict/ { capture=1; next }
       /^## / && capture { exit }
       capture && NF { out = out (out=="" ? "" : " ") $0 }
       END { print out }
     ' "$_verdict_source" 2>/dev/null)"
     # Trim and sanitize for YAML frontmatter (strip double-quotes, collapse whitespace).
     _rationale_text="$(printf '%s\n' "$_rationale_text" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"
     ```
   - Then update the existing rationale assignment to prefer the extracted text when non-empty:
     ```sh
     _mode_label="${_mode:-cooperative}"
     if [ -n "$_rationale_text" ]; then
       _rationale="$_rationale_text"
     else
       _rationale="verdict=${_verdict} derived from surviving_disputes=${_surviving} in ${_mode_label} deliberation"
     fi
     ```
   - Rename `awk` doesn't need the `-v` variant here because the pattern is regex-safe. If the file's existing style uses `awk` with `-v` for other patterns, match that style.
3. **F3 in `scripts/dispatch/adapters/tool/conversus.sh`** (current provider resolution at line ~288):
   - Add a preflight block immediately before `_provider="${CONVERSUS_PROVIDER:-anthropic}"`:
     ```sh
     # F3: auto-preflight CONVERSUS_PROVIDER=claude-code under Anthropic OAuth.
     # The default --provider anthropic path hits a server-side concurrency
     # policy gate on OAuth credentials (not a transient rate limit; retries
     # don't help). See references/architecture.md "Conversus Adapter —
     # Operator Notes". Operators who already set CONVERSUS_PROVIDER keep
     # their setting.
     if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
       if grep -qE '"(oauth|subscription|access_token)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
         echo "note: detected Anthropic OAuth auth with no ANTHROPIC_API_KEY; auto-setting CONVERSUS_PROVIDER=claude-code (see references/architecture.md)" >&2
         CONVERSUS_PROVIDER=claude-code
         export CONVERSUS_PROVIDER
       fi
     fi
     _provider="${CONVERSUS_PROVIDER:-anthropic}"
     ```
   - The `[ -z "${CONVERSUS_PROVIDER+set}" ]` test distinguishes "unset" from "explicitly empty"; only unset triggers auto-preflight. Operators who want to override the heuristic can set `CONVERSUS_PROVIDER=anthropic` explicitly.
4. **Update the adapter header comment block** (around lines 35-49 where the provider-selection rule was documented in commit `32ab6ea`) to note the new auto-preflight behavior. One to three new lines, no restructuring.
5. **Write `scripts/verify/m026-p02-gate-verdict-reliability.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - **F1**: rationale block contains the awk-based `## Verdict` extractor and the fallback to the 32ab6ea synthesized formula (grep for the awk pattern and the fallback phrase).
   - **F1 smoke**: create a temp synthesis file with a `## Verdict` section containing a known paragraph, invoke the adapter in a mode that exercises the rationale block (stub mode doesn't — this path is real-mode only; either mock the structure via direct awk call in the verifier, or construct a minimal harness that drives the real rationale-extraction code path with a synthetic `_run_output_dir`).
   - **F2**: adapter references `arbiter/resolution.md` (grep the source literal).
   - **F2 smoke**: with both `arbiter/resolution.md` and `summary/final.md` written to a temp dir, the extracted rationale matches the arbiter file's `## Verdict` paragraph, not the synthesis's.
   - **F3**: preflight block is present and correctly-gated — grep for `CONVERSUS_PROVIDER+set`, `ANTHROPIC_API_KEY`, `.conversus/auth.json`, and the `claude-code` assignment.
   - **F3 smoke**: construct an isolated HOME with a mock `.conversus/auth.json` containing `"oauth": true` and no `ANTHROPIC_API_KEY`, invoke a read-only adapter path (e.g., `check` — not `gate`, which would attempt a real run). Assert the stderr `note:` line fires. With `ANTHROPIC_API_KEY=x` set, no preflight fires. With `CONVERSUS_PROVIDER=anthropic` explicitly set, no preflight fires regardless of other conditions.
   - Note: F3's auto-preflight is in the `gate` subcommand, not `check`. The smoke harness may need to invoke a minimal `gate` path; if that requires a binary the harness can't reach, reduce the F3 smoke to pattern-match-only on the source file and defer full integration to `tests/test-conversus-adapter-shim.sh` section 3 (out of scope for the verifier).

## Must-Haves

Addresses phase must-haves:
- "Truth: rationale resolved from verdict text with arbiter preference; auto-preflight on OAuth" (T04 owns)
- Artifact: `scripts/verify/m026-p02-gate-verdict-reliability.sh`

## Verification

```
bash scripts/verify/m026-p02-gate-verdict-reliability.sh
bash scripts/verify/m026-p02-adapter-invariants.sh
```

Both must exit 0. The invariants verifier must still pass — no regression introduced by F1/F2/F3.

## Inputs

### From Previous Tasks

- `scripts/dispatch/adapters/tool/conversus.sh` (from T01): edition-detection helpers available; header comment already documents `CONVERSUS_PROVIDER=claude-code` manual-set rule (will be updated to also reflect auto-preflight).

### From Disk (Pre-existing)

- `.orchestrator/milestones/M026/phases/P01/POST-P01-FINDINGS.md` — authoritative scope for F1/F2/F3.
- `.orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md` §6 — empirical grounding for the false-PASS.
- `references/architecture.md` — the "Conversus Adapter — Operator Notes" section documents the rule that F3 automates.
- `~/.conversus/auth.json` — operator's auth state (read-only probe).
- `~/Sites/conversus-oss/engine/auth.py` — read-only reference for auth.json schema (CON-5 permits read).

## Constraints

- **CON-1** (adapter invariants): exit codes / frontmatter keys / env-var set unchanged. Only the *content* of `rationale:` and the *auto-selection* of `CONVERSUS_PROVIDER` change; both are shape-preserving.
- **CON-2** (Bash 3.2): awk + sed + grep only; no `declare -A`, no `mapfile`, no process substitution.
- **CON-5** (read-only-on-conversus-trees): the one-time inspection of `~/Sites/conversus-oss/engine/auth.py` is a read; no write.
- **Operator-override precedence**: an explicit `CONVERSUS_PROVIDER=<anything>` always wins. F3 only fires when the env var is unset (`[ -z "${CONVERSUS_PROVIDER+set}" ]`).
- **Graceful degradation**: if `~/.conversus/auth.json` is malformed or unreadable, F3 silently does nothing (no warning spam, no crash). The existing `CONVERSUS_PROVIDER=${CONVERSUS_PROVIDER:-anthropic}` default path still runs.
- **Stderr discipline** (DC-5): F3's `note:` line goes to stderr. F1/F2 produce no runtime output; they only shape the rationale written to `gate-result.md`.
- **AD-19** (single-script-file Check shape): verifier uses no inline compound bash.

## Expected Output

- `scripts/dispatch/adapters/tool/conversus.sh` — modified: F1 awk-extractor + F2 arbiter-preference (≤20 lines), F3 preflight block (≤12 lines), header comment updated (≤3 lines). Total delta ≤ +40 lines.
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` — created (~80-120 lines, given the smoke-harness breadth).
- Rationale in `gate-result.md` now reads as the verdict text when the synthesis/arbiter file emits a `## Verdict` section; falls back cleanly otherwise.
- A `gate` invocation under OAuth (no `ANTHROPIC_API_KEY`, auth.json present with OAuth marker) auto-sets `CONVERSUS_PROVIDER=claude-code` and emits a single `note:` line to stderr.
- All exits 0 per Verification section.

---
schema_version: "1.0"
task: "T03"
phase: "P03"
milestone: "M026"
name: "Knowledge graduation — two MEM entries (edition-resolution pattern + paid-escape-hatch convention) + index rebuild (FR-13, AD-8)"
depends_on: []
---

## Prerequisites

- `knowledge/` taxonomy on disk has these subdirectories: `patterns/`, `conventions/`, `lessons/`, `spec/`, `archive/`. There is **no** `decisions/` subdirectory; spec 027 §FR-13 and roadmap §P03 Boundary Map reference `knowledge/decisions/MEM*.md` as the destination, but no other consumer or scaffolder script in this repo references `knowledge/decisions/`. Per the P03 plan-phase notes, this task places the two graduated entries under the closest matching existing categories (`patterns/` and `conventions/`).
- `KNOWLEDGE-INDEX.md` at the repo root is the consolidated index. The last existing MEM entry is MEM028. T03 adds MEM029 (pattern) and MEM030 (convention).
- MEM027 (`knowledge/patterns/MEM027.md`) is the most recent shape exemplar — graduated from M025 with frontmatter (`id`, `scope_tags`, `category`, `confidence`, `created_at`, `last_verified`, `hit_count`, `source_unit`, `source_type`, `supersedes`, `superseded_by`, `relates_to`, `content_hash`) plus body sections `## Problem`, `## Pattern`, `## Gate shape`.
- `scripts/knowledge/rebuild-index.sh` exists and rebuilds `KNOWLEDGE-INDEX.md` from the on-disk `knowledge/**/MEM*.md` files. The verifier uses index re-rebuild as part of its assertion.

## Description

Graduate two M026 decisions into the knowledge layer:

- **MEM029** (`knowledge/patterns/MEM029.md`) — "Edition-resolution two-tier detection (env-var primary, metadata-probe fallback)". Captures the M026/P02 pattern of using a declarative env var as the primary signal and a runtime metadata probe as fallback for runtime-identification questions where path-based detection is infeasible. Reusable for future similar runtime-identification problems (e.g., distinguishing build editions of any installed Python package, distinguishing runtime modes of MCP servers).

- **MEM030** (`knowledge/conventions/MEM030.md`) — "Paid-escape-hatch env-var convention". Captures the convention that when an OSS-default tool requires reach-through to a paid alternate, the escape is named `<TOOL>_EDITION=paid` (or analogous) rather than a path or magic value. Reusable for future tool migrations.

After creating both files, rebuild `KNOWLEDGE-INDEX.md` via `scripts/knowledge/rebuild-index.sh` so MEM029 and MEM030 appear in the index.

T03 also creates the verifier `scripts/verify/m026-p03-mem-graduation.sh`.

## Steps

1. **Read MEM027 as a shape exemplar**:

   ```sh
   cat knowledge/patterns/MEM027.md
   ```

   Note: frontmatter keys, ordering, body section headers (`## Problem`, `## Pattern`, `## Gate shape`).

2. **Create `knowledge/patterns/MEM029.md`** with the following content:

   ```markdown
   ---
   id: MEM029
   scope_tags: "[project], [milestone:M026]"
   category: patterns
   confidence: 0.90
   created_at: 2026-04-24
   last_verified: 2026-04-24
   hit_count: 0
   source_unit: "M026/P02"
   source_type: consolidation
   supersedes: ""
   superseded_by: ""
   relates_to: [MEM018, MEM030]
   content_hash: ""
   ---

   # MEM029: Edition-resolution two-tier detection (env-var primary, metadata-probe fallback)

   ## Problem

   When an installed package has multiple distributable builds (OSS vs paid, dev vs prod, community vs enterprise) that share a single PyPI/npm/etc. package name and venv install path, path-based detection is infeasible — both editions install to the same canonical path under pip/pipx/npm. A consumer that needs to know which edition is currently active (for routing decisions, edition-aware diagnostics, or telemetry) cannot rely on the binary path alone.

   The M026 conversus migration surfaced this concretely: both `~/Sites/conversus-oss` (OSS) and `~/Sites/conversus` (paid) publish as the `conversus` PyPI package and install to `~/.local/pipx/venvs/conversus/`. A path-difference check at the `~/Sites/` level is fragile (operators may install via pipx-only with no source clone, or install via brew, or develop one tree and install the other) and fails entirely under the single-venv reality.

   ## Pattern: two-tier detection

   1. **Primary signal — operator declaration via env var**. A `<TOOL>_EDITION=<value>` env var is the operator's declarative signal. The consumer trusts the declaration without further probing. This makes the active edition explicit, audit-trail-visible (env-var is logged with the dispatch), and portable across host-OS and install-method differences. Bad values (typos) emit a single-line stderr warning and fall through to tier 2 — never silently accept a bad declaration.

   2. **Fallback — runtime metadata probe**. When the env var is unset, query the package's installed metadata (`pip show <pkg>` for Python; `npm ls <pkg> --json` for Node; equivalent registry probes for other ecosystems). Parse a stable identifying field (`Home-page:` for Python pip; `repository.url` for Node) and key on a canonical substring (e.g., `*-oss` in the URL). The probe is read-only, side-effect-free, and runs under the consumer's existing subprocess discipline. On probe failure (subprocess fails, field absent, value unrecognized), emit `edition=unknown reason=metadata-probe-failed` rather than guessing.

   3. **Short-circuit cases**. Stub mode (test-only) is edition-agnostic by design — emit `edition=unknown reason=stub` without probing. Operator-supplied absolute overrides (e.g., `<TOOL>_HOME`) attempt the metadata probe at that location but fall through to `edition=unknown reason=home` if the probe fails — the operator already knows what they pointed at.

   ## Output contract

   The consumer's edition resolver emits two structured stdout lines per resolution: `edition=<oss|paid|unknown>` and `reason=<env-override|metadata-probe|metadata-probe-failed|stub|home|command-v|fallback>`. Line ordering is the verifiable contract. Warnings (e.g., bad env-var value) go to stderr. The same stdout shape is consumed downstream by JSONL emitters (M026/P02/T02 pattern) and by edition-aware-diagnostic refusal blocks (M026/P03/T01 pattern).

   ## Gate shape

   - **Edition-detection contract test** (e.g., `scripts/verify/m026-p02-edition-detection-contract.sh`): exercise every resolver branch (env-override, stub, metadata-probe, metadata-probe-failed) and assert the `edition=`/`reason=` line ordering and values.
   - **Stderr/stdout discipline** (cross-cuts MEM015 DOCTOR Structured Output Protocol): structured fields go to stdout in fixed line order; warnings go to stderr; never cross-contaminate.
   - **Bash 3.2 compatibility**: probe subprocess via plain `"$venv_py" -m pip show <pkg>` — no process substitution, no command-substitution-containing-pipes.

   ## Reusable beyond M026

   - Distinguishing editions of any pip/pipx-installed Python tool that publishes under one package name across multiple build channels.
   - Distinguishing runtime modes of MCP servers where the binary is the same but the active configuration tier differs.
   - Distinguishing local development vs CI installations where path differs but the operator's declarative intent is the load-bearing signal.

   See: `scripts/dispatch/adapters/tool/conversus.sh` `_resolve_edition` for the canonical implementation; MEM030 for the paired env-var naming convention.
   ```

3. **Create `knowledge/conventions/MEM030.md`** with the following content:

   ```markdown
   ---
   id: MEM030
   scope_tags: "[project], [milestone:M026]"
   category: conventions
   confidence: 0.90
   created_at: 2026-04-24
   last_verified: 2026-04-24
   hit_count: 0
   source_unit: "M026/P02"
   source_type: consolidation
   supersedes: ""
   superseded_by: ""
   relates_to: [MEM018, MEM029]
   content_hash: ""
   ---

   # MEM030: `<TOOL>_EDITION=<value>` env-var convention for OSS-default escape hatches

   ## Problem

   When an orchestrator integration flips its default from a paid build to an OSS build, the operator still needs a discoverable, undestructive way to reach the paid build for one-off invocations (debugging a paid-only feature, reproducing a paid-build regression, running a preset that depends on paid-only upstream plumbing). Three anti-patterns to avoid:

   1. **Path-only escape** — requiring the operator to set `<TOOL>_HOME=/explicit/path/to/paid/build` per invocation. Undiscoverable, easy to forget, and brittle across machines with different install paths.
   2. **Magic-value escape** — using a generic feature flag like `USE_PAID=1` or `LEGACY_MODE=1`. Doesn't express edition intent, doesn't compose with other build-channel distinctions, and is inconsistent across tools.
   3. **No escape** — routing all paid-only access through a separate command or wrapper. Forces the orchestrator to maintain two parallel invocation paths with the same surface, doubling test burden.

   ## Convention: `<TOOL>_EDITION=<edition-name>`

   1. **Naming**: `<TOOL>_EDITION` (uppercase tool name + literal `_EDITION` suffix). Examples: `CONVERSUS_EDITION`, `<NEWTOOL>_EDITION`. Reads naturally in shell history, in JSONL telemetry, and in operator-facing error messages.

   2. **Values**: closed enum `oss|paid` (or analogous closed enum for non-OSS-vs-paid distinctions like `community|enterprise` or `free|pro`). Enforce the closed enum with a stderr warning on unrecognized values; fall through to the metadata probe (see MEM029) rather than silently accepting.

   3. **Precedence**: env-var declaration is **primary**. Metadata-probe fallback is secondary. Operator-supplied absolute overrides (`<TOOL>_HOME`) trump both — they're an explicit "use exactly this binary" instruction. Resolver order from highest to lowest precedence: STUB (test-only) → PATH (`command -v`) → `<TOOL>_HOME` → `<TOOL>_EDITION`-aware user-local probe.

   4. **Diagnostic surface**: the `check` subcommand of the integration's adapter MUST emit `edition=<value> reason=<resolution-tag>` on stdout so the resolved edition is visible to the operator and to telemetry without a separate probe call.

   5. **Telemetry shape**: every JSONL record emitted by the integration adapter MUST include an `edition` field alongside the existing identifying fields (e.g., `adapter_version`, `gate_id`). Place adjacent to the version field for readability and for adjacency-invariant tests (M026/P02/T02 pattern).

   6. **Refusal diagnostic**: when an upstream artifact (preset, config, manifest) declares `edition_required: <edition>` and the resolved edition does not match, the integration MUST refuse the invocation BEFORE any heavy work, with a stderr diagnostic naming both the requirement and the escape — `<TOOL>_EDITION=<required-edition>` (M026/P03 FR-11 pattern).

   ## Why a convention

   The M026 migration is the first OSS-default escape-hatch landing in this repo. Future migrations (e.g., when M010 ships and the orchestrator starts integrating with multiple LLM-provider editions, or when M023 ships and design-renderer adapters need to distinguish freemium tier vs paid tier) will face the same shape. Naming it as a convention now means the next migration can copy the pattern verbatim instead of re-deliberating the env-var name in each milestone.

   ## Gate shape

   - **Env-var-name lint** (advisory): a future `scripts/diagnostics/check-edition-conventions.sh` could grep adapter-tree env-var references and flag any non-`<TOOL>_EDITION`-shaped escape-hatch names.
   - **JSONL `edition` field presence**: every `*_invocation` record from an edition-aware adapter MUST contain an `edition` field. Verify with `scripts/verify/m026-p02-jsonl-edition-field.sh` (existing) — extend the pattern when adding a second edition-aware adapter.
   - **Refusal regex stability**: `paid-only.*<TOOL>_EDITION=paid` (case-insensitive) is the SC-7 contract for paid-only-on-OSS refusals; preserve verbatim across tools so operator runbooks transfer.

   See: `scripts/dispatch/adapters/tool/conversus.sh` for the canonical implementation; MEM029 for the paired two-tier-detection pattern.
   ```

4. **Rebuild the knowledge index**:

   ```sh
   bash scripts/knowledge/rebuild-index.sh
   ```

   This regenerates `KNOWLEDGE-INDEX.md`. After the rebuild, `KNOWLEDGE-INDEX.md` should list both MEM029 and MEM030.

5. **Create `scripts/verify/m026-p03-mem-graduation.sh`** (single-script-file shape, AD-19, Bash 3.2):

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-mem-graduation.sh
   # Verifies M026/P03/T03: two graduated MEM entries exist and KNOWLEDGE-INDEX is rebuilt.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   MEM029="${REPO_ROOT}/knowledge/patterns/MEM029.md"
   MEM030="${REPO_ROOT}/knowledge/conventions/MEM030.md"
   INDEX="${REPO_ROOT}/KNOWLEDGE-INDEX.md"

   for f in "$MEM029" "$MEM030"; do
     base="$(basename "$f")"
     if [ ! -f "$f" ]; then _fail "${base}: file missing"; continue; fi
     if grep -q '^id: MEM' "$f"; then _pass "${base}: has frontmatter id field"; else _fail "${base}: missing 'id:' frontmatter"; fi
     if grep -q '^source_unit: "M026/P02"' "$f"; then _pass "${base}: source_unit pinned to M026/P02"; else _fail "${base}: source_unit not pinned to M026/P02"; fi
     if grep -q '^category:' "$f"; then _pass "${base}: has category field"; else _fail "${base}: missing 'category:' frontmatter"; fi
   done

   if grep -qE '^MEM029 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM029"; else _fail "KNOWLEDGE-INDEX.md missing MEM029"; fi
   if grep -qE '^MEM030 ' "$INDEX"; then _pass "KNOWLEDGE-INDEX.md lists MEM030"; else _fail "KNOWLEDGE-INDEX.md missing MEM030"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

6. **Run the verifier**:

   ```sh
   bash scripts/verify/m026-p03-mem-graduation.sh
   ```

   Expected:

   ```
   ----
   SUMMARY: m026-p03-mem-graduation.sh pass=8 fail=0
   PASS: m026-p03-mem-graduation.sh
   ```

   (3 frontmatter checks × 2 files + 2 index checks = 8 PASS lines.)

## Must-Haves

Addresses phase must-haves:
- "Truth: two knowledge-layer MEM*.md entries are graduated for this milestone; KNOWLEDGE-INDEX.md lists both"
- Artifacts: `knowledge/patterns/MEM029.md`, `knowledge/conventions/MEM030.md`, `KNOWLEDGE-INDEX.md` (modified), `scripts/verify/m026-p03-mem-graduation.sh`

## Verification

```
bash scripts/knowledge/rebuild-index.sh
bash scripts/verify/m026-p03-mem-graduation.sh
```

Verifier must exit 0 with `SUMMARY: ... pass=8 fail=0` and `PASS:` final line.

## Inputs

### From Previous Tasks

None — T03 is independent within P03.

### From Disk (Pre-existing)

- `knowledge/patterns/MEM027.md` — shape exemplar (most recent graduation, M025 source).
- `KNOWLEDGE-INDEX.md` — flat index, regenerated by `scripts/knowledge/rebuild-index.sh`.
- `scripts/knowledge/rebuild-index.sh` — index regenerator.
- `scripts/dispatch/adapters/tool/conversus.sh` — referenced in both MEM bodies as the canonical implementation.

## Constraints

- **Knowledge taxonomy fidelity**: place graduated entries under existing categories (`patterns/`, `conventions/`). Do NOT create a new `decisions/` subdirectory — no consumer references it. The plan-phase notes section documents this deviation.
- **MEM ID monotonicity**: MEM IDs are append-only. Use MEM029 and MEM030 (next two after MEM028).
- **Frontmatter shape**: match MEM027's keys and ordering exactly. The index regenerator parses frontmatter — divergence breaks the index rebuild.
- **AD-19** (single-script-file Check shape): verifier uses no compound bash that triggers the harness heuristic.
- **Idempotent**: re-running `scripts/knowledge/rebuild-index.sh` produces a byte-identical `KNOWLEDGE-INDEX.md` (the regenerator already enforces this; the verifier asserts the result, not the regenerator's idempotency).

## Expected Output

- `knowledge/patterns/MEM029.md` — created (~70-100 lines).
- `knowledge/conventions/MEM030.md` — created (~70-100 lines).
- `KNOWLEDGE-INDEX.md` — modified (two new MEM rows added by the regenerator).
- `scripts/verify/m026-p03-mem-graduation.sh` — created (~40-50 lines).
- `bash scripts/verify/m026-p03-mem-graduation.sh` exits 0 with `SUMMARY: ... pass=8 fail=0`.

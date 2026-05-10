---
schema_version: "1.0"
type: conversus-oss-dogfood
milestone: "M026"
phase: "P01"
created_at: "2026-04-23"
status: final
verdict_interpretation: commentary-not-authoritative
parent_artifacts:
  - specs/027-conversus-oss-migration/conversus/oss-early-review.md
  - .orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md
  - .orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md
conversus_version: "conversus 0.3.0 (editable install ~/Sites/conversus-oss, pipx venv ~/.local/pipx/venvs/conversus, Python 3.14)"
provider: mock (end-to-end) + claude-code (real-signal, §6) + no direct-anthropic retry (see §3)
paths_verified_by_this_smoke:
  - oss_binary: /Users/brettkellgren/.local/bin/conversus
  - oss_lint_binary: /Users/brettkellgren/.local/bin/conversus-lint
  - oss_venv_python: /Users/brettkellgren/.local/pipx/venvs/conversus/bin/python
  - oss_tree: /Users/brettkellgren/Sites/conversus-oss/ (NOT written — CON-5)
  - orchestrator_preset_raw: templates/conversus-presets/spec-pressure-test.yml (NOT modified)
  - adapter: scripts/dispatch/adapters/tool/conversus.sh (NOT invoked)
---

# Conversus-OSS Dogfood Smoke — Post-P01 Empirical Validation

Purpose: empirically validate the parity-matrix re-framing that the four
drifts surfaced in `oss-early-review.md` are **preset-vs-tree** drifts,
not OSS-vs-paid drifts. If they are, P02 planning is unblocked. If
they are not, the parity matrix's re-framing is wrong and P02 must
revisit.

**This file is commentary, not a gate verdict.** The orchestrator adapter
was not invoked; this smoke probes the OSS CLI directly with progressive
config variants that isolate each of the four drifts.

## §1. Isolation Probes — Each Drift Fires Identically on OSS

Four progressive config variants were hand-built in `/tmp/` (outside
repo), each fixing the previous drift to surface the next. All four
drifts fire against OSS 0.3.0 exactly as the parity matrix predicts.

| # | Probe | Input shape | Exit | Error surface | Drift row in parity matrix |
|---|---|---|---|---|---|
| 1 | `conversus validate templates/conversus-presets/spec-pressure-test.yml` | raw preset with `---` frontmatter + body | 1 | `yaml.composer.ComposerError: expected a single document in the stream` at `engine/config.py:600` | "Top-level YAML contract — frontmatter rejection" |
| 2 | `conversus validate /tmp/oss-smoke-p01-drift2.yml` | frontmatter stripped; `system_prompt:` kept; no `role:`; `output:` as structured object | 1 | `TypeError: unsupported operand type(s) for /: 'PosixPath' and 'dict'` at `engine/config.py:624` (output-path resolve) | "Top-level `output:` — object-vs-string semantic" |
| 3 | `conversus validate /tmp/oss-smoke-p01-drift3.yml` | `output:` as string path; `system_prompt:` kept; no `role:` | 1 | `Error: agents[0] ('blue-advocate'): 'prompt' is required (provide it inline or via a preset).` | "`agents[].prompt:` (OSS) vs `agents[].system_prompt:` (paid)" |
| 4 | `conversus validate /tmp/oss-smoke-p01-drift2-only.yml` | `prompt:` correct; no `role:` | 1 | `Error: red-blue mode requires at least one agent with role: red.` | "`agents[].role` required under `mode: red-blue` on OSS" |

**Call**: all four drifts manifest on OSS with the exact semantics the
parity matrix catalogs. The re-framing (preset-vs-tree, not OSS-vs-paid)
is **empirically supported** — OSS's rejection messages match the paid
tree's per the fs-inspection line numbers in the matrix (OSS 600/624/427/708;
paid side byte-identical at `engine/config.py`).

**One nuance**: drift 2 (output-shape) manifests as a raw unhandled
`TypeError` rather than a structured validation error. The parser tries
to path-resolve `output:` before walking it as a schema. This is an
uglier failure surface than oss-early-review.md's table implied, and
should be captured as a synth-layer signal for P02: **the synthesizer
must strip or rewrite `output:` before passing the config to OSS**, not
merely rename it — leaving the wrong shape in produces an unhandled
exception, not a structured "output should be a string" message.
Failure-mode parity between OSS and paid on this point: both trees use
the same `output: Path` model binding at `engine/config.py` (OSS line
102, paid line 82), so both would raise the same `TypeError`. Parity
holds; P02 synth-layer hardening justified on both sides.

**Parser precedence observation**: drifts fire in order frontmatter →
output-shape → prompt-field → role-required. The parser short-circuits
at the first violation. A synth layer that addresses them in that order
walks the preset through validate cleanly without cascading surprises.

## §2. Post-Translation End-to-End Run — Mock Provider

Config `/tmp/oss-smoke-p01-run.yml` (translation-equivalent to
`/tmp/oss-smoke-spec027.yml` from the early review; preset with all
four drifts resolved):

```
conversus validate /tmp/oss-smoke-p01-run.yml
# → Config valid. Mode: red-blue. Cost estimate: 9 total LLM launches.
#   Per-phase: review(2) → cross-review(2) → revision(2) → disputes(2) → synthesis(1)

conversus run /tmp/oss-smoke-p01-run.yml --provider mock
# → exit 0
# → 5 phases complete, 9 dispatches, summary/final.md emitted
# → output tree: /tmp/oss-smoke-p01-run-out/{blue-advocate,red-advocate,summary}/
```

End-to-end pipeline runs cleanly. No new regressions vs. the early review's
mock run.

### §2a. `linter.output_contract` parses OSS mock synth into adapter keys

Invoked the module against the mock `summary/final.md` using the OSS
pipx venv's Python:

```
~/.local/pipx/venvs/conversus/bin/python -m linter.output_contract \
  /tmp/oss-smoke-p01-run-out/summary/final.md --mode red-blue
# → exit 0
# → valid JSON emitted with all three adapter-consumed keys at the expected paths:
#     quality_indicators.genuine_disagreements_surviving: 0
#     headline: "Both agents agree on the core trade-off"
#     summary: "2 agents in cooperative mode completed 5 phases..."
```

This **upgrades the DC-6 spike from fs-inspection GO to empirical GO**
on the mock path. The spike already confirmed the JSON schema shape by
reading `linter/output_contract.py`; this run proves the same module
actually imports, executes, and emits the documented field names
against a real `summary/final.md` written by OSS's synthesis phase.

**Mock artifact caveat (reproduces #OQ-15)**: the mock synthesizer
produces a stub template that ignores configured mode + agents. The
parsed JSON shows `quality_indicators.mode: "cooperative"` and
`full_analysis` text "Agents: pragmatist, devils-advocate | Mode:
cooperative" despite the config being red-blue with blue/red
advocates. This is a mock-provider-only artifact — `linter.output_contract`
faithfully surfaces what the synth wrote. Real-provider runs will not
exhibit this. P02 stub-mode tests should assert structural keys, not
content — which `spec 027 #OQ-15` already flagged.

## §3. Anthropic Real-Signal Attempt — Intentionally Skipped

The early review hit the PR #29 parallel-429 on first anthropic
contact. OSS 0.3.0 does not contain PR #29 (parity matrix verified-absent).
Retrying into the same upstream bug without sequencing mitigation
would be cargo-cult diagnosis. `conversus status` confirms the operator's
anthropic subscription is still authenticated (expires 2026-04-24
08:56 UTC) — auth is fine; OSS's dispatch concurrency is the blocker.

This confirms the parity-matrix narrow-scope trigger (OQ-2: 5 rows >
3) is driven by the two `verified-absent` rows (PR #28 + PR #29), not
by the drift rows. P02 scope is rightly concentrated on the PR #29
mitigation and the PR #28 shield, not on synth-layer churn for the
four drifts — which, as demonstrated in §1, apply identically to both
editions.

## §4. Orphan Finding — `conversus-lint` Is Not An Adapter Swap Target

The post-verify addendum to the parity matrix flagged `conversus-lint`
as a potential P02 opportunity ("the adapter could switch from `python
-m linter.output_contract` to `conversus-lint` for cleaner invocation").
Direct inspection of the installed binary:

```
conversus-lint --help
# → "Validate conversus templates against the schema."
# → options: --mode {cooperative|red-blue|winner-take-all|prisoners-dilemma}, --verbose
```

`conversus-lint` is a **template-file schema validator** (validates
`presets/role/*.yml` and similar), not a synthesis-output parser. It
is a different tool from `linter.output_contract` despite the
naming proximity. The parity-matrix addendum's framing is misleading
on this point and should be corrected: `conversus-lint` is NOT a
replacement for the adapter's `python -m linter.output_contract`
invocation. The adapter's current module invocation remains the
correct path.

(Running `conversus-lint --mode red-blue --verbose` against OSS's
bundled templates reports "Checked 7 template files. All 7 templates
valid against schema." — informational only.)

## §5. Conclusions for P02

1. **Parity-matrix re-framing is correct**. The four drifts are
   preset-vs-tree issues that fire identically on OSS and paid.
   Synthesizer-layer work in P02 applies to both editions, not just
   OSS, and can be scoped without edition branching.

2. **Parser precedence is frontmatter → output-shape →
   prompt-field → role-required**. Synth layer should handle in that
   order.

3. **Output-shape (drift 2) is a TypeError on both editions, not a
   structured validation error**. P02 synth must strip/rewrite
   `output:` — leaving the object shape produces an unhandled
   exception.

4. **DC-6 empirically confirmed beyond spike verdict**. Adapter's
   `python -m linter.output_contract` invocation works unchanged
   against OSS 0.3.0 summaries. No key-rename map, no output-path
   remap. FR-7 / SC-6 byte-equivalence claim is credible.

5. **`conversus-lint` is not a P02 adapter-swap target**. The
   parity-matrix addendum's §2 entry should be corrected. (Parity
   matrix will be updated as part of this dogfood closeout if the
   operator chooses; this file flags the inaccuracy.)

6. **PR #29 real-signal validation remains deferred**. Plan-phase
   for P02 should decide between: (a) adapter-side serialization
   shim, (b) documented `--provider ollama` path for integration
   tests, or (c) OSS version-gate on FR-8's OSS branch. All three
   options remain viable; this smoke adds no new evidence
   constraining the choice.

**Net**: P02 planning is unblocked with high confidence. The
synth-layer work is real, edition-agnostic, and the exact consumption
path the adapter uses (`linter.output_contract` JSON → adapter verdict
derivation) is demonstrated working on OSS today.

## §6. Real-Signal Gate Run — `CONVERSUS_PROVIDER=claude-code` on Spec 027

Per the `feedback_conversus_provider_claude_code` memory (subscription
OAuth operators must use `CONVERSUS_PROVIDER=claude-code` — the
default `--provider anthropic` path is a policy gate, not a transient
rate limit), the gate was re-attempted on spec 027 via the
subprocess path. This is the originally-intended invocation: the
orchestrator adapter gating the spec pre-discuss against the
`spec-pressure-test` preset.

### Invocation

```
CONVERSUS_PROVIDER=claude-code \
  scripts/dispatch/adapters/tool/conversus.sh gate \
    spec-pressure-test \
    specs/027-conversus-oss-migration/spec.md \
    specs/027-conversus-oss-migration/conversus/gate-result.md
```

### Pipeline result: success

- Adapter synth layer translated preset → OSS-compliant config cleanly
  (confirms §5 conclusion #1: all four drifts absorbed by
  `conversus-synth.py` without code change).
- Binary resolution, venv-python extraction, and adapter flow all clean.
- Five phases × 9 agent dispatches, **all ✓** — no PR #9 AttributeError,
  no PR #28 classification failures, no 429s. OSS's
  `ClaudeCodeProvider` class (at `engine/execution/providers/claude_code.py`,
  exports `ClaudeCodeProvider` and `SubprocessProvider`, NOT the
  `_retry` / `_parse_output` symbols the rule's patch-check targets —
  OSS has refactored to a class-based architecture) works end-to-end
  for a 2-agent red-blue deliberation.
- Wall time: ~12 minutes (review 153s + cross-review 113s + revision
  125s + disputes 145s + synthesis 179s). Within the feedback memory's
  ~15-25 min expected band, closer to the lower bound on this config.

### Adapter exit: verdict=PASS (exit 0)

The adapter's verdict-derivation pipeline (`python -m
linter.output_contract` → `quality_indicators.genuine_disagreements_surviving`
→ PASS/BLOCK mapping) returned **PASS** with 0 surviving disputes.

### CRITICAL FINDING: gate verdict is FALSE-PASS on `claude-code` provider

The synthesis file (`summary/final.md`, 22 lines of real claude-sonnet
deliberation content) says the exact opposite of what the adapter
reported. Verbatim from the synthesis:

> **Final Verdict: Proceed with Conditions**
>
> The migration has merit but requires two P0 mitigations before
> implementation:
>
> 1. Complete parity audit with actual evidence
> 2. Resolve arbiter component contract
>
> The risk register identifies 9 total threats with specific
> mitigations, acceptance criteria, and effort estimates.

And from the red-advocate's `disputes.md`:

> **Final recommendation: BLOCK.** This proposal violates Constitution
> Principle II and poses unacceptable risks to system integrity. It
> should be routed through `orchestrator:discuss` for fundamental
> scope revision before any implementation work begins.
> Zero attacks withdrawn. Three major concessions by Blue Team.
> Two attacks escalated.

The parsed `gate-result.md` frontmatter meanwhile reads:

```
verdict: "PASS"
disputes: 0
rationale: "0 agents in red-blue mode completed 0 phases.
            0 convergence points, 0 surviving disputes."
```

The `0 agents / 0 phases / 0 convergence points` is the smoking gun:
`linter.output_contract`'s red-blue parser found none of its expected
structural markers in the synthesizer's prose output and defaulted
every quality-indicator field to 0. The pipeline ran; the parser
failed to extract signal. The adapter trusted the 0 and mapped it to
PASS.

### Root cause (hypothesis)

Per the feedback-memory rule: **claude-code provider output is terse
(1-2 KB per review) and framed differently** than direct-API output.
The actual per-phase files bear this out — all 10 agent output files
total 103 lines combined; most files reference "the document I
produced" or "the comprehensive Final Unmitigated Risks document"
rather than containing the deliberation content inline. The claude-code
subprocess appears to be doing its work in a Write-tool-produced
artifact scratch space that the orchestrator never sees — only short
summaries reach the output tree. The synthesizer follows the same
pattern: 22 lines of prose summary instead of the structured tally
(`Surviving disagreements: N` / `Convergence points: N` / etc.) that
`linter.output_contract`'s red-blue mode pattern-matches.

This is a **new parity row not in the parity matrix**: the
`linter.output_contract` ↔ synthesizer output-shape contract is
intact on mock (mock emits a stub matching the contract) and
presumably intact on direct-API anthropic (early review's 429 prevented
testing) — but **broken on `--provider claude-code`** because the
subprocess path produces prose-shaped output that the parser can't
tally.

### Verdict reliability matrix (post-dogfood)

| Provider path | Pipeline completes? | Output-contract parseable? | Verdict reliable? |
|---|---|---|---|
| `--provider mock` | YES (§2) | YES — stub matches contract (§2a) | YES but content-worthless (stub) |
| `--provider anthropic` (API key) | Untested this smoke | Assumed yes (pre-OSS adapter worked this way) | Assumed yes |
| `--provider anthropic` (OAuth) | NO — PR #29 policy gate | N/A | N/A |
| `--provider claude-code` (OAuth) | YES | **NO — prose output defeats parser** | **NO — false-PASS** |

This row set supersedes the P02 framing of "choose between adapter-side
serialization shim / ollama fallback / version-gate". The real choice
matrix for P02 is now:

1. **Fix synthesizer prompt under claude-code** so it emits the
   structural tally `linter.output_contract` expects. This is likely
   an upstream conversus issue (the synthesizer agent's system prompt
   isn't enforcing the output shape when the provider is a subprocess
   rather than a direct-API call). May require an upstream PR.
2. **Make the adapter's verdict derivation provider-aware** — fall
   back to a prose-parsing path (or refuse to emit PASS) when
   `CONVERSUS_PROVIDER=claude-code`.
3. **Document the false-PASS failure mode** and require operators to
   read `summary/final.md` by eye on the claude-code path, treating
   `gate-result.md` as advisory only.

P02 must pick one. Option 3 is the minimum-viable shipping posture;
option 2 is the correct adapter-side fix; option 1 is the right
upstream fix.

### Substantive findings on spec 027 (surfaced by the deliberation)

The deliberation content is load-bearing for P02 / orchestrator:discuss:

- **Red team (full BLOCK)**: Constitutional violation of Principle II
  (Evidence Before Claims) — spec 027 makes compatibility claims
  without a completed parity audit. Recommends routing through
  `orchestrator:discuss` for scope revision before implementation.
- **Red team additional attacks (escalated, not withdrawn)**: arbiter
  component crisis (OSS may lack PASS/BLOCK verdict functionality that
  5 production callers depend on — this smoke demonstrates that
  crisis empirically via §6 above); 7 structural OSS incompatibilities
  from OQ-9 through OQ-15 (the four drift rows + the synthesis-crux +
  the PR #28 / #29 absences) that contradict parity assumptions.
- **Blue team concessions (3 major)**: conceded that compatibility
  claims preceded verification (Constitutional violation conceded);
  conceded the parity matrix was empty at time of spec authoring
  (note: this is no longer true — the matrix is now final, a fact
  blue team didn't have in-context at deliberation time); conceded
  that cross-milestone coordination assumptions are under-specified.
- **Blue team successful defenses (3 core safety mechanisms)**: the
  escape-hatch posture, the rollback mechanism, and the opt-in
  gate-point design remain defensible.
- **Remaining disputes (3 surviving despite blue team revision)**:
  arbiter contract resolution path, parity-audit completion sequencing,
  FR-8 dual-edition test feasibility on OAuth-only infrastructure.

Blue team's revision ("shift from 'seamless compatibility' to 'safe
migration with adaptive scope'") is the posture P02 should adopt. Red
team's BLOCK recommendation is strictly stronger than the adapter's
false-PASS and should be treated as the operative verdict for pre-P02
routing decisions.

### Net conclusions (post-§6)

1. **OSS + claude-code provider path runs cleanly end-to-end** — first
   real-signal confirmation. PR #9 / PR #28 concerns from the rule's
   patch-check are not reproducible on OSS's class-based architecture.
2. **The adapter's verdict contract is broken on claude-code** — the
   false-PASS above means any gate run on this provider path cannot
   be trusted without reading the synthesis by eye. This is a P02
   must-fix.
3. **Spec 027 has substantive issues surfaced by the deliberation**
   that P02 planning must absorb — specifically the Evidence-Before-Claims
   sequencing (parity audit was empty at spec-authoring time; now
   final, so the Red team critique on that axis is partially obsolete)
   and the arbiter PASS/BLOCK contract (validated as a real risk by
   the very false-PASS this run produced).
4. **The parity matrix needs a new row**: "Synthesizer output shape
   under `--provider claude-code` — prose vs. structural tally. OSS
   and paid both affected (assumed — paid untested this smoke).
   Verdict: verified-drifted-from-parser-contract on OSS; parity-to-paid
   unverified."

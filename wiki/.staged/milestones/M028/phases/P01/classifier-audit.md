---
schema_version: "1.0"
type: phase-artifact
artifact: classifier-replay-audit
milestone: M028
phase: P01
task: T01
created_at: 2026-04-29
---

# M028/P01/T01 — Classifier Replay Audit

## Preface

This document is the verbatim replay of every M028 source event through the existing [M021](../../../../milestones/M021/index.md) shape classifier (`scripts/verify/lib/shape-classifier.sh`, git SHA `12fcd98`, last touched 2026-04-17). The classifier exposes `classify_command "<cmd>"`, which prints exactly one line: `allow`, `reject:<class>`, or `rewrite:<replacement>`. The reject classes referenced below — including the load-bearing `compound-chain-gt2` (which AP-009 in `ANTIPATTERNS.md` documents) — are stable per M021/P03.

T01 is fact-only: each section records the source citation, the verbatim command (or, where the screenshot is out-of-tree and the spec only narrates the shape, the reconstructed command bytes), the classifier's verbatim verdict, and the observed-in-the-wild behavior captured by the spec. **Root-cause attribution and the collapse-vs-full-milestone decision live in T03**, not here.

The replay shim that produced each verdict block is `scripts/verify/m028/p01-classify-one.sh`, sourcing the classifier and dispatching `classify_command "$1"`. Probes were staged under `tmp/m028-p01/` and invoked through `scripts/util/run-probe.sh`. The Finding F Stop-hook event is **not** a Bash classification target — its line is recorded as observed-only because the failure surface is the runtime adapter + installer (per FR-3, FR-4), not the classifier matrix.

Source-event count: **9** (one per Finding A/B-each-of-4/C/D/G screenshot, plus operator-reported Stop-hook for F). The spec's Findings A–G yield 9 SE rows below; T03 maps these onto Findings and Acceptance Scenarios.

## SE-01: Finding A — hook fails-open in consumer project (bbt-companion)

- **Source**: Finding A, screenshots 4–7 (2026-04-25/26 sweep, paths under `/Users/brettkellgren/Sites/bbt-companion/...`)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:24` (problem-statement bullet 1) and `specs/031-autonomous-hardening-v3/spec.md:42-48` (User Story 1)
- **Observed behavior in the wild**: The shape-guard hook never produced a `REJECT:` diagnostic against any of the four bbt-companion screenshots, indicating it never ran. The spec's root-cause narration (line 24) attributes this to `scripts/hooks/pre-bash-shape-guard.sh:39-42` resolving the classifier via `$CLAUDE_PROJECT_DIR`, which does not exist inside a downstream consumer project, so the hook falls through to `exit 0` (passthrough at lines 118–121 of the hook).

### Verbatim command

The Finding A symptom is portability, not a single command — the screenshots show a *family* of commands that would otherwise be classified by SE-02 / SE-03 / SE-04 / SE-05 (the Finding B set) had the hook actually fired. SE-01 is recorded for completeness as the *non-firing* event class. A representative member of the family appears in SE-02 below.

### Existing-classifier verdict

```
not-applicable: hook-never-invoked (portability gap, see SE-02..SE-05 for the in-family commands)
```

## SE-02: Finding B #1 — backtick-in-grep-regex (Screenshot 4)

- **Source**: Finding B #1, Screenshot 4 (2026-04-26)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:26` (problem-statement bullet 2) and `specs/031-autonomous-hardening-v3/spec.md:70` (US-2 acceptance scenario 2)
- **Observed behavior in the wild**: Claude Code's parser read the backtick inside the grep regex as a command-substitution attempt and prompted; the hook did not reject (the spec narrates this as outside the M021 matrix and the reason AP-010 is reserved).

### Verbatim command

````
grep '^- `bash scripts/util/' commands/dispatch.md
````

### Existing-classifier verdict

```
allow
```

## SE-03: Finding B #2 — quoted-arg-newline-hash (Screenshot 3)

- **Source**: Finding B #2, Screenshot 3 (2026-04-25)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:26` and `specs/031-autonomous-hardening-v3/spec.md:70`
- **Observed behavior in the wild**: Newline + `#` inside a quoted `--last-action` arg tripped Claude Code's path-validation security heuristic ("args hidden from validation") and prompted; the hook did not reject. AP-011 is reserved for this shape.

### Verbatim command

````
bash scripts/state/auto-state.sh set --last-action "T01 done
# trailing comment"
````

### Existing-classifier verdict

```
allow
```

## SE-04: Finding B #3 — multiline-quoted-script (Screenshot 5)

- **Source**: Finding B #3, Screenshot 5 (2026-04-26)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:26` and `specs/031-autonomous-hardening-v3/spec.md:70`
- **Observed behavior in the wild**: A multi-line `node -e "…"` body hit Claude Code's `ansi_c_string` parser fallthrough and prompted; the hook did not reject. AP-012 is reserved for this shape.

### Verbatim command

````
node -e "const x = 1;
console.log(x);
"
````

### Existing-classifier verdict

```
allow
```

## SE-05: Finding B #4 — unquoted-brace-glob (Screenshot 6)

- **Source**: Finding B #4, Screenshot 6 (2026-04-26)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:26` and `specs/031-autonomous-hardening-v3/spec.md:70`
- **Observed behavior in the wild**: Raw `{2,3,4,5}` outside quotes triggered brace-expansion heuristics that AP-007 only catches *inside* quotes; the hook did not reject. AP-013 is reserved for this shape.

### Verbatim command

````
ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md
````

### Existing-classifier verdict

```
allow
```

## SE-06: Finding C — investigation compound chain (Screenshot 1)

- **Source**: Finding C, Screenshot 1 (2026-04-25)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:28` (problem-statement bullet 3, "agents reach for `grep …; echo \"---\"; grep …`")
- **Observed behavior in the wild**: Compound chain (`grep ... ; echo "---"; grep ...`) — agent invented the shape mid-investigation because no canonical wrapper covered "grep one pattern across multiple files with separators". Spec narrates this as the Finding E "agents invent compound shells" class.

### Verbatim command

````
grep -n classify_command scripts/verify/lib/shape-classifier.sh; echo "---"; grep -n reject_lookup scripts/hooks/pre-bash-shape-guard.sh
````

### Existing-classifier verdict

```
reject:compound-chain-gt2
```

## SE-07: Finding D — destructive rm + && + ls (Screenshot 2)

- **Source**: Finding D, Screenshot 2 (2026-04-25)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:28` and `specs/031-autonomous-hardening-v3/spec.md:104` (US-4 acceptance scenario 2; FR-15)
- **Observed behavior in the wild**: Claude Code prompted on `rm` regardless of `Bash(...)` allowlist entries; the compound `&&` chain made it worse but the destructive-op prompt fires shape-independently. The hook does not interpose a reject because top-level connector count is exactly 2 (`&&` + redirect-only `2>&1`), inside `compound-chain-gt2`'s threshold.

### Verbatim command

````
/bin/rm -f .orchestrator/milestones/M028/phases/P01/*.txt && ls .orchestrator/milestones/M028/phases/P01/*.txt 2>&1
````

### Existing-classifier verdict

```
allow
```

## SE-08: Finding F — Stop-hook `command not found` (operator-reported)

- **Source**: Finding F, operator-reported during [M018](../../../../milestones/M018/index.md) close (2026-04-28)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:24` (problem-statement bullet 1, second half) and `[.orchestrator/proposals/M028-autonomous-hardening-v3.md](../../../../proposals/M028-autonomous-hardening-v3.md):79-100` (Finding F section)
- **Observed behavior in the wild**: Stop-hook fired `orchestrator-post-verify: command not found` at session end on the orchestrator's own repo. `~/.claude/settings.json` carried 5 duplicate `Stop` wrappers and 7 duplicate `PreToolUse` Bash wrappers naming `orchestrator-post-verify` / `orchestrator-before-commit`; none on PATH; none carrying `_orchestrator_managed: true`. Three distinct bugs (bare-name emission, install-side dedup absent, flag-less orphans) presenting as one symptom. Adapter+installer issue, not classifier.

### Verbatim command

Not a Bash classification target — the failure surface is the runtime adapter (`scripts/dispatch/adapters/runtime/claude-code.sh:170-189`) emitting bare command names plus the absent install-side dedup in `scripts/util/settings-merge.sh`. The "command" Claude Code attempted to resolve was the bare token `orchestrator-post-verify` (not a shape-classifiable bash invocation).

### Existing-classifier verdict

```
not-applicable: adapter+installer issue (FR-3, FR-4, FR-5, FR-7 — out of classifier scope)
```

## SE-09: Finding G — xargs sh -c body-descent (2026-04-28 22:25)

- **Source**: Finding G, operator screenshot 2026-04-28 22:25 (Claude Code permission-prompt UI on the orchestrator's own repo — Finding A's downstream-portability gap is **not** the explanation here)
- **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:69` (US-2 acceptance scenario 1) and `[.orchestrator/proposals/M028-autonomous-hardening-v3.md](../../../../proposals/M028-autonomous-hardening-v3.md):104-124` (Finding G section)
- **Observed behavior in the wild**: Claude Code surfaced a "Do you want to proceed?" prompt; the "Yes, and don't ask again for:" rule offered the literal byte-segment `xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'`. The classifier did **not** reject pre-prompt, so the operator faced a literal-bytes allowlist offer that would silently degrade the shape guard if accepted. The spec narrates this as a sibling of Finding C (classifier under-matches embedded compound shapes); AP-014 is reserved for the `sh -c '<body>'` body-descent rule.

### Verbatim command

````
find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'
````

### Existing-classifier verdict

```
reject:compound-chain-gt2
```

## Replay summary table

| SE | Finding | Source | Existing verdict | AP currently cited |
|----|---------|--------|------------------|--------------------|
| SE-01 | A | Screenshots 4–7 (bbt-companion) | not-applicable: hook-never-invoked | (portability — none) |
| SE-02 | B #1 | Screenshot 4 | allow | (gap — AP-010 reserved) |
| SE-03 | B #2 | Screenshot 3 | allow | (gap — AP-011 reserved) |
| SE-04 | B #3 | Screenshot 5 | allow | (gap — AP-012 reserved) |
| SE-05 | B #4 | Screenshot 6 | allow | (gap — AP-013 reserved) |
| SE-06 | C | Screenshot 1 | reject:compound-chain-gt2 | AP-009 |
| SE-07 | D | Screenshot 2 | allow | (destructive-op layer — none) |
| SE-08 | F | Operator-reported Stop hook | not-applicable: adapter+installer | (out of classifier scope) |
| SE-09 | G | Screenshot 2026-04-28 22:25 | reject:compound-chain-gt2 | AP-009 |

The token `AP-009` appears explicitly in the SE-06 and SE-09 rows above, anchoring the must-have substring assertion in `scripts/verify/m028/p01-replay-coverage.sh`.

## Reproduction notes

- Classifier git SHA: `12fcd98` (last touched 2026-04-17, file `scripts/verify/lib/shape-classifier.sh`).
- Replay shim: `scripts/verify/m028/p01-classify-one.sh` (throwaway per the T01 task plan; AD-19 single-script-file shape).
- Probes (one per SE row, staged for `scripts/util/run-probe.sh`): `tmp/m028-p01/probe-se02.sh`, `probe-se03.sh`, `probe-se04.sh`, `probe-se05.sh`, `probe-se06.sh`, `probe-se07.sh`, `probe-se09.sh`. SE-01 and SE-08 are observed-only — the hook never fired (SE-01) or the failure surface is non-classifier (SE-08).
- Verdicts above are byte-exact stdout from the classifier; no post-processing.

## What this audit does **not** do

- **Does not interpret the verdicts.** Whether `reject:compound-chain-gt2` for SE-09 is sufficient (and AP-014 body-descent therefore unnecessary), or whether the spec's narration that "AP-009 refuses to reject" is at odds with the live classifier output, is a T03 question. T01 records facts only.
- **Does not recommend collapse-vs-full-milestone.** That recommendation lives in T03 (`p01-collapse-decision-recorded.sh`-gated) with this audit cited as input evidence.
- **Does not modify any M021 surface.** Per the M028 spec's Non-Goals (`specs/031-autonomous-hardening-v3/spec.md:181`), `shape-classifier.sh`, `pre-bash-shape-guard.sh`, and `tests/fixtures/m021-prompt-corpus.txt` remain immutable. T01 is read-only against all three.

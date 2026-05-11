# Dead-Infrastructure Linter Conventions — Reader-Precision Definition

**Audience**: Anyone authoring or extending `scripts/diagnostics/check-dead-infra.sh`, adding readers for config-knob keys in `templates/orchestrator-config-default.yml`, or recording dynamic-reader exceptions in `CONFORMANCE.md`.

**Captured**: 2026-05-11 alongside follow-on amendment Item 7 of `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md`. Ship-now finding from the original 2026-05-11 XXII+XII blind deliberation (P1 #7 in `.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/summary/final.md`; modified A2 + S5 convergence). The 2026-05-11 dual-grounding rerun did not contradict this finding (per `blind-rerun-with-conformance/COMPARISON.md` Divergence 6); the original's specificity stands.

**Governs**: the inherited conversus Tier 2 XII (No Dead Infrastructure) normative body's "at least one reader in the codebase" clause as applied to orchestrator's config surface.

## Why a precise reader definition

The orchestrator's component-tier scope under Tier 2 XII is "every config-knob leaf in `templates/orchestrator-config-default.yml` MUST have at least one reader in the codebase." Without mechanical precision on what counts as a reader, the linter cannot make a deterministic decision; ambiguity at the definition layer cascades into either false positives (a real reader misclassified as absent) or false negatives (a non-reader misclassified as present), and either failure mode degrades enforcement value below the threshold where the linter is worth running.

Mechanical precision here means the linter — `scripts/diagnostics/check-dead-infra.sh` — can decide per-key by pattern match against the codebase plus a small allowlist file, without invoking human judgment, LLM compliance, or runtime introspection.

## The three reader classes (exhaustive)

A reader is **any one** of the following three pattern classes. The list is **exhaustive**: a code construct that does not match one of (a), (b), or (c) below is not a reader, regardless of how a human reading the construct might intuit its behavior.

### (a) Direct shell variable assignment via a canonical helper

The most common reader shape: a shell line that names the config key and assigns its value to a shell variable using the orchestrator's canonical helper. The canonical helper for shell consumers is `config_get` (or any function/alias that delegates to the same resolver). Example:

```bash
runtime=$(config_get runtime.kind)
```

The linter matches this class by string-searching for `config_get` invocations whose first argument literally equals the key's documented dotted YAML path. The argument MUST appear as a literal string in the source — it MUST NOT be assembled from variables or string concatenation at runtime.

### (b) jq or yq expression addressing the key by its full documented YAML path

The second reader shape: a `jq` or `yq` invocation that extracts the key by its full documented YAML path. Example for the key `runtime.kind`:

```bash
val=$(yq '.runtime.kind' orchestrator-config.yml)
```

The linter matches this class by string-searching for `jq` or `yq` invocations whose expression argument literally contains `.runtime.kind` (or the canonical dotted form of the key in question). The path MUST be the full documented path — partial-path matches (e.g., `.runtime`) do NOT discharge the reader requirement for `runtime.kind` specifically, even though a human reader could in principle traverse the parent object to reach the leaf.

### (c) Reader-exception entry in CONFORMANCE.md's reader-exception table

The escape hatch for dynamic readers that legitimately exist but cannot be matched by classes (a) or (b) — for example, code that iterates over a key set computed at runtime and reads each key dynamically. Example dynamic-reader patterns:

```bash
# Pattern 1 — eval-based dynamic key read
eval "val=\${$key_var}"
```

```bash
# Pattern 2 — jq with a runtime-substituted key argument
val=$(jq --arg k "$key" '.[$k]' orchestrator-config.json)
```

The linter does NOT attempt to understand or simulate dynamic dispatch. Instead, a dynamic reader is recorded as an entry in CONFORMANCE.md's reader-exception table. The entry MUST record:

1. The canonical YAML path of the key being read.
2. The verbatim access pattern (the exact shell or expression form used).
3. The file path(s) where the pattern appears.

An exception entry that asserts a dynamic reader exists without recording its access pattern is **invalid and treated as absent** — the linter treats the corresponding key as having no class-(c) reader. This is a deliberate strictness: an assertion-without-evidence escape hatch would defeat the linter's enforcement.

## What is NOT a reader

The following code constructs are explicitly NOT readers, regardless of how plausibly a human might read them as evidence of liveness:

- **Comments mentioning the key** (e.g., `# reads runtime.kind on startup`). Comments are not executed; they cannot satisfy a liveness requirement.
- **Reference-doc prose mentioning the key** (e.g., this very document mentioning `runtime.kind` in an example does NOT count as a reader for `runtime.kind`).
- **Commit messages mentioning the key**. Git history is not consumable by the running orchestrator.
- **Inline string literals that happen to contain the key's dotted form** but are passed as arguments to non-reader functions (e.g., a logging call that prints the key name as a label).
- **Test fixtures or test assertions that reference the key** without consuming its value via class (a) or (b). A test that asserts "the key exists in the YAML" is not a reader of the key's value.

The linter's behavior on each non-reader class is to treat the key as having no reader from that construct. Aggregation across the codebase is unaffected: a key with one class-(a) reader and ten comments is "live" by virtue of the single class-(a) reader; a key with zero class-(a)/(b)/(c) readers and ten comments is "dead" regardless of the comments.

## Pairing with the reader-exception table

CONFORMANCE.md hosts the reader-exception table in the inherited conversus Tier 2 XII section. The table's initial state at 2026-05-11 is `(none recorded)` — no dynamic readers currently exist; the 41 known config-knob leaves are all matched by class (a) or class (b). The `(none recorded)` row is itself a load-bearing artifact: it makes the empty-state visible so that auditors do not mistake the table's absence for the table's emptiness.

When a future commit introduces a dynamic reader for a key that previously had only class-(a) or class-(b) readers, the linter's behavior does not change (the key is still live). The reader-exception entry is required only when class (a) and class (b) are both absent and class (c) is the sole basis for the key's liveness.

When a future commit introduces a dynamic reader for a NEW key that has no class-(a) or class-(b) reader anywhere, the linter will report the key as dead unless the reader-exception entry lands in the same commit. This is the intended discipline: the exception table is a co-shipping requirement, not a backfill.

## Linter implementation guidance

`scripts/diagnostics/check-dead-infra.sh` implements the three classes as follows (sketch — actual implementation may vary):

1. For each config-knob leaf in `templates/orchestrator-config-default.yml`, derive the canonical dotted YAML path.
2. Grep the codebase (excluding the template itself and the reader-exception table) for `config_get <path>` literally as an argument — class (a) match.
3. Grep the codebase for `jq` / `yq` invocations whose expression literally contains `.<path>` (with the leading dot) — class (b) match.
4. Parse the reader-exception table in CONFORMANCE.md. For each row whose canonical YAML path matches the current leaf AND whose verbatim access pattern and file-path fields are non-empty, count it as a class-(c) match.
5. If at least one of (a), (b), (c) matches, the key is live. Otherwise, the key is dead.

The linter reports dead keys with their canonical YAML path; auditors then either add a class-(a) / class-(b) reader, add a valid class-(c) exception entry, or remove the dead key from the template.

## Boundary with file-system reachability (Principle VIII)

This document governs **variable-level liveness of config-knob leaves** — the inherited conversus Tier 2 XII territory. File-system reachability of the config files themselves (e.g., is `templates/orchestrator-config-default.yml` referenced by any live code path?) is governed by orchestrator's component-tier Principle VIII (No Dead Infrastructure) via `scripts/diagnostics/run-doctor.sh`. The constitutional boundary is made self-derivable at constitution v2.2.1 in Principle VIII's opening declaration; the evidentiary projection lives in CONFORMANCE.md's "Two-principle boundary" sub-table.

A reader convention question that crosses the boundary (e.g., "does this constitute a reader of the file-system object or of a variable within the file?") is resolved by asking: is the question about whether the file is reachable at all, or about whether a specific key inside the file is consumed? The former is VIII; the latter is Tier 2 XII.

## References

- `.orchestrator/memory/constitution.md` § VIII (file-system scope boundary, self-derivable at v2.2.1).
- `CONFORMANCE.md` § Tier 2 XII — Three-bucket structure (config-knob class).
- `CONFORMANCE.md` § Two-principle boundary (run-doctor.sh ↔ check-dead-infra.sh ↔ Tier 2 XXII triangulation).
- `CONFORMANCE.md` § Reader-exception table (this document's companion artifact).
- `.orchestrator/proposals/M0XX-tier-2-xxii-xii-substantive-followups.md` § Deferred Item 7 (origin).
- `.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/summary/final.md` § P1 #7 (verbatim source text).
- `scripts/diagnostics/check-dead-infra.sh` (linter implementation).
- `tests/test-dead-infra-knobs.sh` (linter test harness).

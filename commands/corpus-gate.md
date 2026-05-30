---
description: "Use when filtering a set of candidate operator/SME questions (or the open questions embedded in a plan/spec/roadmap) through a deterministic corpus-exhaustion gate before they reach a human. Sweeps every configured knowledge store, marks questions already answerable from the corpus, and produces a PASS|BLOCK verdict + an evidence artifact. Reusable across any orchestrator stage that emits questions to a human (discuss, comments, materials-intake, specify, plan-phase, roadmap)."
---

# orchestrator:corpus-gate

A reusable command wrapping the deterministic corpus-exhaustion sweep. Given a
file of candidate questions and a checkpoint name, it searches every configured
knowledge store for each question and emits a `PASS | BLOCK` verdict plus an
evidence artifact. Callers use the verdict to gate human-facing questions:
**no question reaches an operator/SME until the gate proves it isn't already
answered in the project's own knowledge.**

This turns the soft "exhaust the corpus first" habit into structure that can't
be skipped. It is intentionally checkpoint-agnostic — `discuss`, `comments`,
`materials-intake`, `specify`, `plan-phase`, and `roadmap` all invoke the same
adapter with their own checkpoint label, the same way M011/M013/M014 reuse the
conversus gate with different presets.

**P01 is deterministic (no LLM).** A grep hit is a *candidate* answer, not a
proven one — the gate enforces "read before ask" by marking hit-bearing
questions `HITS` (pending) until the agent dispositions them. The P03 LLM judge
(deferred) upgrades `HITS` into semantic `ANSWERED`/`PARTIAL`/`MENTIONS`
verdicts and auto-resolves answered questions.

## Prerequisites

- **Opt-out, not opt-in.** The gate is enabled by default. A project disables it
  with `corpus_exhaustion.enabled: false` in `.orchestrator/config.yml`; the
  adapter then emits `SKIPPED:` and exits 0 (graceful degradation — a project
  that opted out is never blocked).
- **Store manifest.** The adapter resolves the manifest from
  `corpus_exhaustion.store_manifest_path` (config), falling back to the bundled
  default `templates/corpus-store-manifest.yml`. Copy the bundled manifest into
  your project and add project-specific stores (SME-reply drafts, Slack exports,
  handoff docs). Never hardcode store paths.

## Usage

```
bash scripts/dispatch/adapters/tool/corpus-gate.sh \
  gate --checkpoint <name> --generated-at <iso8601> \
  <questions-file> <output-artifact-path>
```

Example:

```
bash scripts/dispatch/adapters/tool/corpus-gate.sh \
  gate --checkpoint sme-packet --generated-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  .orchestrator/scratch/sme-questions.txt \
  .orchestrator/milestones/M042/gates/corpus-exhaustion-sme-packet.md
```

**Exit-code contract** (identical to `conversus-gate`):

- `0` — PASS verdict, OR SKIPPED (feature disabled / manifest absent in
  non-strict mode). Both mean "proceed".
- `2` — BLOCK verdict (at least one question has un-dispositioned corpus hits).
- `1` — adapter error (missing questions file, missing manifest in `--strict`,
  malformed artifact).

### Subcommands

- `check` — report `enabled`, resolved `manifest`, and `manifest_present`.
- `gate [--strict] [--checkpoint <name>] [--generated-at <iso>] [--manifest <path>] <questions-file> <output-path>` — run the sweep, write the artifact, exit per verdict.
- `parse-verdict <artifact-path>` — emit `verdict=PASS|BLOCK` from an existing artifact.

## Questions file format

One question per non-blank, non-comment (`#`) line. An optional leading `[id]`
token is preserved as the question ID. After reading the gate's hit citations,
the agent annotates each hit-bearing question on its line:

```
[Q1] Does the spec require frobnication of widgets?  @disposition=dropped reason: answered in DR-012
[Q2] What is the SME sign-off deadline for stage 3?  @disposition=kept reason: not present in any store
[Q3] Which timezone are the cutoff times expressed in?
```

- `@disposition=dropped` — the corpus already answers it; drop it from the human
  packet (the answer + citation are recorded in the artifact).
- `@disposition=kept` — searched, genuinely open; it stays in the human packet.
- (no annotation) — if the sweep found hits, the question is `HITS` (pending) and
  the gate BLOCKs until you disposition it.

## Workflow (the read-before-ask loop)

1. Author the candidate questions to a questions file.
2. Run `gate`. Questions with corpus hits come back `HITS`; the gate exits `2`.
3. Read the cited `store · path · line` locations in the artifact. For each
   `HITS` question, annotate its line: `@disposition=dropped` (answered) or
   `@disposition=kept` (genuinely open).
4. Re-run `gate`. With no pending `HITS` the gate exits `0`; the surviving
   (non-dropped) questions are the human packet. Show the artifact to the SME as
   provenance ("here is why each question is genuinely open").

## Verdict legend (per question)

- `CLEAN` — zero hits, all required stores searched. Safe to ask.
- `HITS` — ≥1 hit, not dispositioned. **Blocks** (read first).
- `DROPPED` — ≥1 hit, `@disposition=dropped`. Answered; removed from the packet.
- `KEPT` — ≥1 hit, `@disposition=kept`. Genuinely open; stays in the packet.
- `IRREDUCIBLE-WITH-CAVEAT` — zero hits but a required store was unreachable. The
  artifact names the store; surfaced rather than hard-blocked (CON-3/CON-6).

## Idempotency

The sweep is a pure function of (questions file + corpus). Dispositions live on
the question lines, so re-running after annotating is reproducible. The sweep
never calls `date`/`$RANDOM`; pass `--generated-at` for a stable timestamp under
test (CON-7).

## Error Handling

- **Feature disabled / manifest absent** (non-strict) — `SKIPPED:` line, exit 0.
- **`--strict` + disabled/missing-manifest** — `FAIL:` to stderr, exit 1.
- **Questions file missing** — `FAIL: questions file not found`, exit 1.
- **Unreachable required store** — never a hard error; the affected questions are
  marked `IRREDUCIBLE-WITH-CAVEAT` and the store is named in the artifact.

## Reference Files

- `scripts/dispatch/adapters/tool/corpus-gate.sh` — the gate adapter.
- `scripts/knowledge/corpus-exhaustion-sweep.sh` — the deterministic sweep engine.
- `templates/corpus-store-manifest.yml` — bundled default store manifest.
- `templates/corpus-exhaustion-artifact.md` — artifact template + workflow legend.

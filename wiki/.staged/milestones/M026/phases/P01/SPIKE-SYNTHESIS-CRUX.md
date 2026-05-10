---
schema_version: "1.0"
type: spike-report
phase: "P01"
task: "T02"
milestone: "M026"
status: final
created_at: "2026-04-23"
---

# DC-6 Synthesis-Crux Spike — OSS linter.output_contract parseability

## Method

Filesystem-only inspection of the read-only OSS tree at `~/Sites/conversus-oss/`,
cross-referenced against the orchestrator-side adapter at
`scripts/dispatch/adapters/tool/conversus.sh`. No writes to `~/Sites/conversus*`
(CON-5). One read-only `python -m linter.output_contract --help` invocation
against the OSS pipx venv for importability confirmation (no network, no
provider call, no synthesis file written).

- Inspected `~/Sites/conversus-oss/linter/output_contract.py` lines 1-435 in
  full (single 435-line module, parser + Pydantic models + `__main__` CLI).
- Inspected `~/Sites/conversus-oss/engine/output.py` lines 19-336 (output-path
  conventions; `OutputManager.get_synthesis_path` and `_FLAT_LAYOUT_DIRS`).
- Inspected `~/Sites/conversus-oss/engine/phases.py` lines 551-1090 (the
  red-blue / cooperative phase pipeline, including synthesis emission at line
  592 via `output_mgr.get_synthesis_path(round_base=round_base)` and the
  optional Phase-6 arbitration branch).
- Cross-referenced `scripts/dispatch/adapters/tool/conversus.sh` lines 285-322
  (adapter's read-back of `${_run_output_dir}/summary/final.md` and its
  inline `subprocess.run([sys.executable, "-m", "linter.output_contract",
  path, "--mode", mode], ...)` invocation extracting `quality_indicators
  .genuine_disagreements_surviving`, `headline`, `summary`).
- Invoked `~/.local/pipx/venvs/conversus/bin/python -m linter.output_contract
  --help` — exit 0, help text printed (no side effects).

Note: the plan refers to `engine/pipeline.py`. OSS does not ship a file by
that name; the pipeline lives in `engine/phases.py` and the path conventions
in `engine/output.py`. Findings reflect the actual files.

## Findings

### Q1: `python -m linter.output_contract` runs on OSS

YES. The OSS tree ships `linter/output_contract.py` at the exact import path
the adapter consumes. Importability confirmed by running `python -m
linter.output_contract --help` against the conversus pipx venv
(`~/.local/pipx/venvs/conversus/bin/python`); the module loaded, argparse
emitted its help, and the process exited 0:

```
usage: python -m linter.output_contract [-h] [--mode MODE] path

Parse conversus synthesis output into the canonical ConversusOutput JSON
format. Exits 0 on success, 2 on file-not-found.

positional arguments:
  path         Path to a conversus synthesis markdown file.

options:
  -h, --help   show this help message and exit
  --mode MODE  Deliberation mode (default: cooperative).
```

The CLI shape — positional `path` + optional `--mode` — matches the
adapter's invocation at `conversus.sh:298` byte-for-byte.

### Q2: OSS red-blue terminal phase writes `summary/final.md` (or equivalent)

YES. Path is `summary/final.md`, identical to the adapter's expectation at
`conversus.sh:285` (`_synthesis="${_run_output_dir}/summary/final.md"`).

Evidence in `engine/output.py`:

- Line 89-90: `summary_dir = self.output_dir / "summary"` is created
  unconditionally during `OutputManager` setup.
- Line 181-184: `get_synthesis_path()` returns `{base}/summary/final.md`.
- Line 266-272: `get_cross_round_synthesis_path()` returns the top-level
  `{root}/summary/final.md` — the cross-round case still writes to the same
  filename the adapter reads.
- Line 50: `_FLAT_LAYOUT_DIRS = frozenset({"summary", "arbiter"})` confirms
  `summary/` is a stable, layout-pinned directory name.

In `engine/phases.py`, the synthesis phase (line 551 onward) emits to
`output_mgr.get_synthesis_path(round_base=round_base)` (line 592). The
optional Phase-6 arbitration writes to a separate `arbiter/` path
(`get_arbitration_path`) and does NOT overwrite `summary/final.md` — so the
adapter's read of `summary/final.md` remains the canonical synthesis surface
even when arbitration runs.

`oss-early-review.md` mock-run evidence corroborates: OSS red-blue terminated
at the synthesis phase and produced `summary/final.md`.

### Q3: linter.output_contract JSON contains the three adapter-consumed keys

YES. The Pydantic models `ConversusOutput` and `QualityIndicators` define an
exact superset of the adapter's three consumed keys. The module emits via
`result.model_dump_json(indent=2)` (line 433) — Pydantic guarantees the
declared field names appear at the documented nesting.

Adapter consumes (conversus.sh:303-306):
- `quality_indicators.genuine_disagreements_surviving` (int)
- `headline` (str)
- `summary` (str)

OSS module emits (output_contract.py:43-80):

```python
class QualityIndicators(BaseModel):
    agent_count: int
    mode: str
    phases_completed: int
    cross_reviews_performed: int
    genuine_disagreements_surfaced: int
    genuine_disagreements_surviving: int  # <-- key 1, exact match

class ConversusOutput(BaseModel):
    headline: str            # <-- key 2, exact match
    summary: str             # <-- key 3, exact match
    full_analysis: str
    quality_indicators: QualityIndicators
    debate_transcript: str
```

All three adapter-consumed keys are present at the exact nesting and exact
spelling the adapter parses. No rename map required. The OSS module emits a
strict superset (six quality-indicator fields vs. one consumed; five
top-level fields vs. three consumed); the extra fields are discarded by the
adapter's `data.get(...)` calls without error.

The parity matrix at [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md)
classifies `linter.output_contract` and the `engine` modules as
verified-identical between OSS and paid editions; this spike confirms that
verdict by direct inspection rather than by derivation.

## Verdict

Verdict: GO

## Rationale

All three DC-6 questions resolve YES with no rename map and no adapter-side
patch required: (Q1) the OSS module is importable via the same `python -m
linter.output_contract` invocation the adapter already uses, with the exact
positional + `--mode` CLI shape; (Q2) OSS's red-blue pipeline writes the
synthesis to `summary/final.md` — the same path the adapter reads — and the
optional arbitration phase writes to a separate `arbiter/` path that does
not overwrite the synthesis; (Q3) the Pydantic-emitted JSON exposes the
adapter's three consumed keys at the exact nesting (`quality_indicators
.genuine_disagreements_surviving`, top-level `headline`, top-level
`summary`) as a strict superset.

What P02 absorbs: nothing beyond the resolver flip already in scope (FR-1 /
FR-2). The adapter logic at `scripts/dispatch/adapters/tool/conversus.sh`
lines 285-322 needs no modification — the same byte-identical Python
invocation that worked against the paid edition will work against the OSS
edition once the resolver routes to the OSS venv. No key-rename map, no
output-path remap, no JSON-shape adaptation. The DC-6 risk that motivated
this spike does not materialize.

P02-relevant observations:
1. The plan referred to `engine/pipeline.py`; OSS uses `engine/phases.py` +
   `engine/output.py`. P02 should reference the actual file names if it
   needs to cite line ranges.
2. `engine/output.py:50` pins `summary/` as a layout-stable directory name
   via `_FLAT_LAYOUT_DIRS`. P02 can rely on this rather than re-deriving the
   path each release.
3. The OSS module emits a strict superset of consumed keys; if a future
   adapter change wants to surface `phases_completed` or `agent_count` for
   richer telemetry, those fields are already on the wire — no upstream PR
   needed.

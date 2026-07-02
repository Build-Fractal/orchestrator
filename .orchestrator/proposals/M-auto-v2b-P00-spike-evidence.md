# M-auto-v2b — P00 Viability Spike Evidence (concurrent `claude -p` + cost-read)

**Date**: 2026-07-02. **Runner**: pre-specify empirical spike (operator-authorized, "run the P00 spike first"). **Purpose**: settle the red-team's V1 (OAuth concurrency / 429 / session-lock) and V2 (cost readable before next spawn) unknowns BEFORE any fan-out coordinator design — avoiding the M045 P01 "design-first, verify-later" trap.

Harness: `scratchpad/v2b-spike/harness.sh` (+ `analyze.sh`). Solo baseline (1 worker) then 3 concurrent `claude -p --output-format json --permission-mode acceptEdits --max-turns 8` under one live OAuth credential, each in its own dir. Task: compute 7×191, write to RESULT.txt, read back, stop.

> Note: original harness used `--permission-mode bypassPermissions`; the auto-mode safety classifier correctly blocked dropping the permission gate wholesale (not separately authorized). Downgraded to `acceptEdits` — sufficient for the concurrency/cost question, which is permission-mode-independent.

## Result: V1 PASS, V2 PASS

### V1 — concurrent `claude -p` under one OAuth: **PASS (decisive) at N=3**
| worker | exit | subtype | RESULT.txt | stderr 429/session-lock |
|--------|------|---------|-----------|--------------------------|
| solo   | 0    | success | 1337 ✓    | clean (0 bytes)          |
| w1     | 0    | success | 1337 ✓    | clean (0 bytes)          |
| w2     | 0    | success | 1337 ✓    | clean (0 bytes)          |
| w3     | 0    | success | 1337 ✓    | clean (0 bytes)          |

- **No rate-limit / session-lock / overload / quota markers** in any worker's stderr.
- **Parallelism ratio (sum-of-durations / wall-span) = 2.88×** of a max 3.0 → near-perfect true parallelism, NOT serialization.
- **Concurrent wall-span 8s < solo baseline 11s (0.73×)** → concurrency was effectively free at N=3.
- **Directly refutes** the standing KNOWLEDGE concern that "the Anthropic OAuth path 429s as policy gates" — that applies to the raw `anthropic` API path, NOT to concurrent `claude -p` CC-OAuth sessions at N=3.

### V2 — cost readable before next spawn: **PASS**
- Every worker's stdout JSON carried `total_cost_usd` (0.244–0.249), immediately parent-readable via `--output-format json`. This is the driver-side cost source FR-10/FR-19 need. (Distinct from M019 Tier-1 JSONL, which remains the orchestrator's own accounting — but `--output-format json` is a simpler, proven driver-readable source.)

### Isolation: **PASS (basic)**
Each worker wrote correct RESULT.txt in its own directory; no cross-stomp. (Full git-worktree lock isolation + coordinator shared-tree serialization NOT tested here — those are v2c coordinator concerns; the load-bearing OAuth-concurrency unknown is now settled.)

## New finding (feeds the budget-cap design)
Each trivial 2-turn task cost **~$0.245** — the **cold-start floor** of the process-fresh model (every fresh `claude -p` re-pays for CLAUDE.md + hooks + skills + tool-def loading). N process-fresh workers each carry this fixed overhead before real work. Input to FR-10/FR-19 budget design; argues for lean/`--bare`-style workers where OAuth allows.

## Scope of proof / residual
- Proven **floor = 3 concurrent**. Policy ceiling at higher N (8/16) untested — coordinator should cap conservatively and probe the ceiling during build.
- `acceptEdits` worker, minimal task — does not exercise a Bash-heavy `orchestrator:auto` segment under concurrency. Adequate for the concurrency/cost primitive question; a fuller "concurrent real auto segments" soak belongs in the v2c fan-out milestone's own gate.

## Disposition
V1 + V2 resolved → **fan-out is a viable primitive**. The red-team's V1/V2 "cut-if-not-viable" cliffs are lifted. The independent SCOPE finding (too big for one milestone) still stands and is decided separately.

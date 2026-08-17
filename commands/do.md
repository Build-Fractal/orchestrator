---
description: "DEPRECATED — use orchestrator:auto <task> instead. This command is now a thin deprecation shim that forwards to the unified orchestrator:auto entry (scripts/intake/auto-entry.sh) with the legacy interactive low-confidence prompt preserved. Scheduled for removal; see the removal runway below."
---

# orchestrator:do <task>  (DEPRECATED)

> **DEPRECATED — migrate to `orchestrator:auto <task>`.**
>
> `orchestrator:do` has been unified into `orchestrator:auto`. The entire
> one-shot classify-and-route behavior that `do` provided now lives in the
> single `orchestrator:auto` entry driver (`scripts/intake/auto-entry.sh`).
> This command is retained only as a thin **deprecation shim** so existing
> scripted callers of `do-entry.sh` keep working during the migration window.
>
> **Replacement:** `orchestrator:auto "<task>"`

## What the shim does

`scripts/intake/do-entry.sh` is now a thin forwarding shim. On every
invocation it:

1. Emits exactly one deprecation-notice line to stderr.
2. Forwards **all six** legacy flags verbatim to
   `scripts/intake/auto-entry.sh`, prepending `--ambiguity-mode prompt`.
3. Exits with `auto-entry.sh`'s exit code unchanged.

Prepending `--ambiguity-mode prompt` is what preserves `do`'s legacy
interactive low-confidence behavior byte-for-byte: a below-floor `do` caller
still gets the interactive Tier A vs Tier B question (honoring
`--no-prompt-mode`), **not** the auto-native `AUTO:BLOCK_AMBIGUITY` default.
This is the compatibility guarantee that keeps scripted `do` callers from
silently changing behavior across the cutover.

All routing logic — the four-branch classify table, the Tier A degenerate
fast-path, the Tier A+ handoff, and the Tier B/C passthrough — is documented
at `commands/auto.md` and implemented in `scripts/intake/auto-entry.sh`. The
shim itself contains no routing logic.

## Flag forwarding (FR-3)

All six flags forward with **identical effect** through the shim to
`auto-entry.sh`:

| Flag                    | Effect (unchanged)                                          |
|-------------------------|-------------------------------------------------------------|
| `--task <description>`  | the task description.                                       |
| `--yes`                 | skip the single attended confirmation prompt (see below).   |
| `--config <path>`       | override active `config.yml` lookup.                        |
| `--dispatch-stub <s>`   | stand in for the agent runtime (test seam).                 |
| `--scratch-root <dir>`  | forwarded to `route-to-dispatch.sh`.                        |
| `--no-prompt-mode <A\|B\|C>` | bypass the interactive low-confidence `read`.          |

The `ORCH_DO_ENTRY_LOG` env var is inherited through the environment
unchanged, so the low-confidence `unit_close` JSONL record is byte-identical
under either entry.

- Shim: `scripts/intake/do-entry.sh`
- Driver: `scripts/intake/auto-entry.sh`

## `--yes` boundary note (D020 / FR-5)

`--yes` keeps its **narrow** meaning under the shim exactly as before: it
skips the single attended confirmation prompt (the Tier-A+ P02 approval prompt
on the one-shot path, or the preflight confirm on the Tier-C loop path). It
does **not** broaden and it does **not** grant any unattended or destructive
authority. `--unattended` (shipped in P04) is the sole explicit gate for the
unattended/destructive-approval envelope. The shim forwards `--yes`
unchanged; no broadening happens at this layer.

## Removal runway (D021 / #Q-3)

This shim is retained through **at least the next published minor release**.
Removal is gated **no earlier than one published release after this
deprecation ships**. The one-line deprecation notice emitted by the shim
names the concrete **target-removal version: `v0.12.0`**. Removal is a
separate future change, not part of this milestone.

Until removal, `orchestrator:do "<task>"` remains functional — it prints the
deprecation notice and forwards to `orchestrator:auto`.

## Prerequisites / State Check

The orchestrator must already be initialized in the project. Verify:

```bash
test -d .orchestrator
```

If non-zero, run `orchestrator:init` first.

## Idempotency

The entry is one-shot. There is no state machine, no lock file, no
`.orchestrator/milestones/M###/` scaffolding write. Re-running
`orchestrator:do "<task>"` simply re-emits the deprecation notice and
re-forwards to `auto-entry.sh` — there is nothing to resume.

## Error Handling

The shim returns `auto-entry.sh`'s exit code unchanged. Notable codes:

- `64` — usage error (`-h` / `--help` prints the shim usage and exits 64).
- non-zero from `build-context.sh` on the Tier A degenerate fast-path.
- non-zero from `route-to-dispatch.sh` on the Tier A+ handoff.
- `2` — operator cancel at the low-confidence prompt (response `C` or timeout).

## Referenced Scripts/Templates

- `scripts/intake/do-entry.sh` — the deprecation shim (emits the notice,
  forwards all six flags plus `--ambiguity-mode prompt` to the driver).
- `scripts/intake/auto-entry.sh` — the unified `orchestrator:auto` entry
  driver that now backs this command (four-branch one-shot routing table +
  Tier-C loop front-route).
- `scripts/intake/shape-detect.sh` — M024 classifier (verdict + confidence
  enum).
- `scripts/intake/route-to-dispatch.sh` — Tier A+ middle-flow router.
- `scripts/dispatch/build-context.sh` — Quick-profile knowledge inject.
- `commands/auto.md` — the replacement command; full routing documentation.

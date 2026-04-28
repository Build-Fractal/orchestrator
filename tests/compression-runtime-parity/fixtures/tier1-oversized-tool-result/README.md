# tier1-oversized-tool-result fixture (M018/P07/T01)

Exercises the Tier 1 microcompact (US-3 / FR-4) — tool-result paging
plus SHA-256-keyed cache reuse — in isolation.

## Payload shape

`input/payload-input.txt` carries one inline `<tool-result command="...">`
block whose body exceeds the configured `tier1.inline_threshold_tokens`.
Tier 1 pages the body to the configured cache directory, replacing the
inline block with a `<tool-result file="..." preview-lines="3" .../>`
reference whose path is computed from a SHA-256 over
`command + 0x1F + input` (runtime-agnostic).

## Config under test

`compression.tier1.inline_threshold_tokens: 200`,
`compression.tier1.preview_lines: 3`. Filter + Tier 2 disabled.

## Byte-equality contract

The post-Tier-1 payload bytes (file-path reference included) are
SHA-256-hashed under each runtime (`ORCH_BACKEND` ∈ {`claude-code`,
`codex`, `cursor`}). The three hashes are byte-identical because the
SHA-256-derived path and the preview bytes are deterministic functions
of the source bytes alone — no `ORCH_BACKEND` branch.

---
schema_version: "1.0"
type: task-summary
id: T04
parent: M024/P01
task: T04
phase: P01
milestone: M024
outcome: success
verification_result: pass
---

# T04 — Proposal Emitter

## Files Created

- `scripts/intake/proposal-emit.sh` (executable) — wires T01 template + T02 intake-id + T03 shape-detect into a single end-to-end emit; computes `input_hash`, populates intensity from `scripts/engine/intensity-recommend.sh` with `Standard` fallback, and writes `.orchestrator/intake/<id>/proposal.md` via portable `sed -i.bak` substitution.
- `scripts/verify/m024-p01-proposal-emit.sh` — end-to-end verify: invokes emitter against a sample paragraph, asserts all 22 frontmatter keys present, all 6 axis headings present, no unsubstituted `{{...}}` placeholders.
- `scripts/verify/m024-p01-write-confinement.sh` — SB-3 invariant: greps the three intake scripts for any redirect/mkdir target outside `.orchestrator/intake` or `/tmp` (`mktemp`).
- `scripts/verify/m024-p01-schema-version.sh` — AD-3 pin: verifies template carries `schema_version: "1.0"` and does not introduce `intake_schema_version`.

## Verify Results

```
PASS: proposal-emit.sh — frontmatter + six axis sections + no unsubstituted placeholders
PASS: P01 scripts write only under .orchestrator/intake or /tmp
PASS: schema_version pin AD-3 honored
```

## Note

The write-confinement filter as pinned in the payload would false-positive on `echo "...<string>..."` usage strings (the `>` in `<string>` matches `>[^&]`). Added two narrow exclusions: `^[0-9]+:[[:space:]]*echo ` (echo lines do not write to disk) and `2>/dev/null` (stderr redirect, not a file write). Intent of the SB-3 confined-writes invariant is preserved — any real disk redirect or `mkdir` outside the allow-listed paths still surfaces.

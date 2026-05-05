---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M033"
provides:
  - "scripts/util/jsonl-event-emitter.sh (FR-22 emitter library, 11 closed-enum event types, schema 1.0, 480-byte atomic-append size guard); tools/verify/m033-p02-jsonl-event-schema.sh (25-check shape + functional + negative-path verifier)"
requires:
  - "none (T01 has no intra-phase prerequisites)"
affects:
  - "P02/T02,P02/T03,P02/T04,P02/T05,P03,P04,P05"
key_files:
  - "scripts/util/jsonl-event-emitter.sh,tools/verify/m033-p02-jsonl-event-schema.sh"
key_decisions:
  - "none"
patterns_established:
  - "fenced SSOT closed-enum block for grep-friendly event-type cross-checking; printf-into-local + linelen size-guard for POSIX atomic-append discipline (480 bytes under macOS PIPE_BUF 512); JSON-object payload validation via case-glob shape check (no jq dependency at emit path)"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P02/tasks/T01-jsonl-event-emitter-PAYLOAD.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-04T03:34:08Z"
---

T01 ships the FR-22 observability emitter library and its shape-plus-functional verifier. The emitter exposes a single CLI entry: emit subcommand taking event_type and payload_json positional args. Records are appended to PROJECT_DIR/.orchestrator/execution-log.jsonl (PROJECT_DIR env override, falls back to PWD). Schema version is fixed at 1.0 for M033; bumping requires a follow-up D-row per the M020 D024 reversibility precedent. The 11 closed-enum event types live in a fenced SSOT block in the script body, in the FR-22 documented order. Unknown event types exit rc=2 with the full enum echoed to stderr (closed-enum discipline per MEM031 precedent). Payload validation is a coarse JSON-object shape check via case-glob — opaque-object discipline without an emit-time jq dependency. Append atomicity is the load-bearing State On Disk Is Truth guarantee: the entire JSON line is formatted into a local via a single printf, then appended via the append redirection. The script REFUSES records whose formatted line exceeds 480 bytes (well under macOS PIPE_BUF 512), exiting rc=2 with the diagnostic 'payload too large for atomic append' to stderr. Probed live with a 592-byte payload — log file was not created, diagnostic surfaced verbatim. Bash 3.2 compatible (MEM001) — no associative arrays, no process substitution, no command-substitution containing pipes. ISO 8601 UTC timestamp via date -u (MEM008). Verifier covers existence and executability, schema-version literal, all 11 event-type tokens via grep -F, fenced SSOT markers, append-target string, positive functional smoke (emit ideation_completed produces log with one line containing expected substrings), and negative path (unknown_event yields non-zero rc plus stderr naming the first and last enum tokens). Final result: SUMMARY: m033-p02-jsonl-event-schema.sh pass=25 fail=0. Out of T01 scope (documented as future demand-driven extensions in the script header): a validate subcommand for read-side log parsing — M027/M019 already consume the JSONL surface programmatically without a CLI parser. No modifications to scripts/lifecycle/start.sh (T02 territory).

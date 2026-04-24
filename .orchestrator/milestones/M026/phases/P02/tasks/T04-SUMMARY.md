---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M026/P02"
milestone: "M026"
provides:
  - "F1-verdict-text-rationale,F2-arbiter-preference,F3-oauth-auto-preflight,m026-p02-gate-verdict-reliability-verifier"
requires:
  - "T01-edition-detection,T02-jsonl-edition-field,T03-dual-edition-test"
affects:
  - "scripts/dispatch/adapters/tool/conversus.sh"
key_files:
  - "scripts/dispatch/adapters/tool/conversus.sh,scripts/verify/m026-p02-gate-verdict-reliability.sh"
key_decisions:
  - "F3-keyed-on-access-token-plus-oauth-subscription-alternation,F3-scoped-to-CONVERSUS_PROVIDER-unset-via-+set-param-expansion,F1-prefers-arbiter-then-synthesis-with-awk-Verdict-extractor,verifier-F3-smoke-is-detection-replay-not-end-to-end-gate"
patterns_established:
  - "detection-replay-smoke-harness-for-deep-gate-logic,awk-section-paragraph-extraction-with-newline-collapse"
drill_down_paths:
  - ".orchestrator/milestones/M026/phases/P01/POST-P01-FINDINGS.md,.orchestrator/milestones/M026/phases/P01/DOGFOOD-SMOKE-OSS.md"
duration: "40"
verification_result: "pass"
completed_at: "2026-04-24T22:21:45Z"
---

Closes POST-P01-FINDINGS F1/F2/F3 and OQ-16 (false-PASS on CONVERSUS_PROVIDER=claude-code). F1 completes the partial 32ab6ea rationale-from-summary fix by preferring the first paragraph of a Markdown '## Verdict' section when present, extracted via a 4-rule awk program with newline/whitespace collapse for frontmatter safety; falls back to the synthesized verdict=V derived from surviving_disputes=N in MODE formula when no Verdict section exists. F2 toggles the verdict-text source to arbiter/resolution.md when that file exists in the conversus run output dir; summary/final.md remains the fallback and the source of structural fields parsed by linter.output_contract. F3 adds an auto-preflight block immediately before the _provider assignment: when CONVERSUS_PROVIDER is unset per [-z ], ANTHROPIC_API_KEY is empty, and ~/.conversus/auth.json exists with an access_token/oauth/subscription marker, the adapter exports CONVERSUS_PROVIDER=claude-code and emits a single 'note:' line to stderr. Keyed the grep alternation on 'access_token' per read of conversus-oss engine/auth.py line 340 (CredentialStore.save writes access_token/refresh_token/expires_at/token_type; access_token is the reliable OAuth marker since API-key mode never writes auth.json). Header comment block updated with 6 new lines documenting the auto-preflight. Total adapter delta: +38 net (budget: +40). Verifier has 26 assertions (F1 static + F1 smoke + F1 fallback + F2 static + F2 smoke + F2 fallback + F3 static + F3 smoke x 5 override-permutations + header + bash-3.2 discipline); F3 smoke is a detection replay against isolated HOME/auth.json rather than an end-to-end gate run, since F3 lives deep in the gate subcommand after binary+synth; documented in the verifier header. All 5 regression guards pass: m026-p02-adapter-invariants.sh (29 assertions), m026-p02-edition-detection-contract.sh (18), m026-p02-jsonl-edition-field.sh (30), m026-p02-dual-edition-test-shape.sh (10), tests/test-conversus-adapter-shim.sh (4+1 skip).

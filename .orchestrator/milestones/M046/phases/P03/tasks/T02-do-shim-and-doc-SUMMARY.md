---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M046"
provides:
  - "scripts/intake/do-entry.sh rewritten as a thin deprecation shim (one stderr notice + verbatim forward to auto-entry.sh --ambiguity-mode prompt, exit code preserved); commands/do.md rewritten as the deprecation-shim doc (D021 removal runway + D020 --yes boundary note)"
requires:
  - "scripts/intake/auto-entry.sh (T01) accepting the six do flags plus --ambiguity-mode"
affects:
  - "T04 (bundle stages the shim skill), T05 (shim-parity + shim-forward verifiers)"
key_files:
  - "scripts/intake/do-entry.sh,commands/do.md"
key_decisions:
  - "D021 target-removal version named as v0.12.0 (no earlier than one published release after M046 deprecation ships; current tree 0.10.4-dev); pass-through forward form ( + prepended --ambiguity-mode prompt) chosen over re-parsing flags to guarantee identical flag handling and byte-parity; -h/--help intercepted before the notice to preserve exit-64 usage semantics"
patterns_established:
  - "deprecation-shim: single stderr notice then direct (no-eval) bash-forward preserving argv boundaries and exit code; artifacts remain byte-identical to a direct driver invocation because the notice is stderr-only"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P03/"
duration: "720s"
verification_result: "pass"
completed_at: "2026-07-14T00:23:26Z"
---

Rewrote scripts/intake/do-entry.sh from the 347-line one-shot driver into a thin deprecation shim that emits exactly one stderr deprecation notice (naming target-removal version v0.12.0 and pointing at commands/do.md) then forwards all six legacy flags verbatim with a prepended --ambiguity-mode prompt to scripts/intake/auto-entry.sh via a direct no-eval bash invocation, returning auto-entry.sh's exit code unchanged; -h/--help is intercepted first so exit-64 usage semantics are preserved; rewrote commands/do.md as the deprecation-shim doc carrying a prominent DEPRECATED banner naming orchestrator:auto, the D021 removal-runway language (retained through at least the next published minor, removal no earlier than one published release after deprecation ships, concrete target v0.12.0), the FR-3 six-flag identical-effect note with pointers to both do-entry.sh and auto-entry.sh, and the D020 --yes narrow-meaning boundary note (--unattended is the separate destructive gate); auto-entry.sh/shape-detect.sh/route-to-dispatch.sh/build-context.sh/auto-loop.sh untouched; all seven plan Verification commands pass and a scratch dispatch-stub smoke run confirmed the notice-then-forward path exits 0 with the deprecation notice present on the do path and absent on the auto path.

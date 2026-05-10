---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M021"
provides:
  - "scripts/util/run-probe.sh wrapper invoking staged bash probes from approved roots only, plus m021-p01-run-probe.sh gate"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "scripts/util/run-probe.sh"
key_decisions:
  - "none"
patterns_established:
  - "run-probe wrapper replaces cat>/tmp/x.sh<<EOF / bash /tmp/x.sh shape that trips heredoc-expansion + bare-tmp-invocation heuristics (AD-3); approved-root prefix allowlist (/tmp, /private/tmp, /var/folders, /private/var/folders, <repo>/tmp) gates invocation"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P01/tasks/T03-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-17T16:51:09Z"
---

Created scripts/util/run-probe.sh — Bash 3.2 compatible wrapper that validates a single path argument, rejects empty strings with exit 2, rejects usage errors with exit 2, canonicalizes relative paths against PWD, and uses case-glob prefix matching to accept only /tmp/, /private/tmp/, /var/folders/, /private/var/folders/, and <repo>/tmp/ roots (exit 3 on miss) per macOS symlink handling. Missing/unreadable files exit 1. Successful paths invoke bash <abs_probe> with full stdio inheritance and no env injection (composition point with with-env.sh). Created scripts/verify/m021-p01-run-probe.sh gate with 7 assertions: /tmp staged probe happy path, child exit-code forwarding (rc=9), missing approved-root file exit 1, out-of-root /etc/hosts exit 3, missing-arg exit 2, empty-string-arg exit 2, project <repo>/tmp/ staged probe happy path. All 7 PASS, gate final line 'PASS: m021-p01-run-probe.sh'. Deviation from plan literal: macOS BSD mktemp does not expand X's when a suffix follows (template /tmp/foo.XXXXXX.sh literally creates foo.XXXXXX.sh), causing collisions across calls; changed gate templates to /tmp/m021-p01-probe.XXXXXX (suffix-free) — behavior preserved, collision avoided. No declare -A, mapfile, readarray, process substitution, or lowercase-expansion in either file.

---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M035"
provides:
  - "references/installation.md ## Verifying integrity operator-facing section (3 subsections: Path 1 sigstore keyless cosign verify-blob recipe with canonical-repo identity URL https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION + OIDC issuer https://token.actions.githubusercontent.com + Path 2 SHA-256 fallback shasum -a 256 -c SHA256SUMS --ignore-missing recipe + What to do if verification fails recovery procedure with search.sigstore.dev Rekor link); tools/verify/m035-p05-installation-doc-verifying-integrity.sh task-grain verifier (9 grep -F literal-string assertions BATTERY: pass=9 fail=0 AD-19 single-script shape)"
requires:
  - "from:P02/T03 what:references/installation.md ## Channel-specific metadata files section (insertion anchor); from:P05/T03 what:.github/workflows/release.yml signing identity URL pattern (Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION canonical pattern T04 documents byte-identically)"
affects:
  - "P05"
key_files:
  - "references/installation.md,tools/verify/m035-p05-installation-doc-verifying-integrity.sh"
key_decisions:
  - "D004 (sigstore keyless signing — T04 documents the operator-side verify against the same identity URL T03 signs against); FR-11 (operator-facing integrity-verification doc surface); CON-3/AP-009 (compound-chain shape-guard honored — verifier uses 9 independent grep -F invocations no chains); AD-19 (verifier single-script-file shape with BATTERY-line output)"
patterns_established:
  - "self-contained-operator-recipe (verification copy must be runnable end-to-end without other-doc indirection — every command shows exact flags + URLs + expected output); identity-URL-lockstep-with-signing-workflow (doc identity URL byte-identical to .github/workflows/release.yml signing path — drift makes verification fail end-to-end; verifier asserts the literal canonical-repo URL substring); two-path-defense-in-depth (recommended sigstore primary + no-cosign-required shasum fallback; SHA256SUMS itself signed for operators wanting both paths); grep-F-literal-match-shape (markdown punctuation like ## and ### confuses regex — switching to grep -q -F -- removes that hazard for doc-shape verifiers)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T04-installation-doc-verifying-integrity-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-09T01:13:20Z"
---

T04 documents the operator-side integrity-verification recipe in references/installation.md § Verifying integrity. Two paths: (1) sigstore keyless via cosign verify-blob with the canonical identity URL https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION + OIDC issuer https://token.actions.githubusercontent.com (byte-identical to what T03 signs against); (2) shasum -a 256 -c SHA256SUMS --ignore-missing for operators without cosign. Defense-in-depth: SHA256SUMS itself is signed so operators can run Path 1 against SHA256SUMS then Path 2 against artifacts. Failure-recovery subsection links to search.sigstore.dev Rekor transparency log + repo issue tracker. Verifier tools/verify/m035-p05-installation-doc-verifying-integrity.sh emits BATTERY: pass=9 fail=0.

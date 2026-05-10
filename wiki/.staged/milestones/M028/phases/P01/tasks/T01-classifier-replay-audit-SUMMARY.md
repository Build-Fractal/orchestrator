---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M028"
provides:
  - "classifier-replay audit covering all 9 M028 source events (Findings A-G); per-event classifier verdict captured verbatim from M021 shape-classifier.sh git SHA 12fcd98; replay-coverage verifier"
requires:
  - "from:specs/031-autonomous-hardening-v3/spec.md what:Findings A-G source events; from:M021/P03 what:scripts/verify/lib/shape-classifier.sh classify_command API; from:M021/P04 what:tests/fixtures/m021-prompt-corpus.txt as shape reference (read-only)"
affects:
  - "P01/T03 collapse-decision (consumes audit as evidence input); P03 classifier-extension (audit fixes which SEs need new AP-010..AP-014 rules); P05 cross-project replay (audit lists the 9 SEs to replay)"
key_files:
  - ".orchestrator/milestones/M028/phases/P01/classifier-audit.md;scripts/verify/m028/p01-replay-coverage.sh;scripts/verify/m028/p01-classify-one.sh"
key_decisions:
  - "9 source events enumerated (SE-01 Finding A non-firing, SE-02..SE-05 Finding B four shapes, SE-06 Finding C, SE-07 Finding D, SE-08 Finding F adapter+installer non-Bash, SE-09 Finding G); SE-06 and SE-09 already reject under M021 as compound-chain-gt2 (AP-009); SE-02..SE-05 and SE-07 currently classify as allow (the gap M028 closes via AP-010..AP-014); SE-01 + SE-08 are non-classifier events (portability + adapter-emission)"
patterns_established:
  - "staged-probe replay shape: write probe under tmp/<milestone>-<phase>/ then invoke via scripts/util/run-probe.sh, source the classifier and call classify_command verbatim, capture stdout byte-exact for the audit's fenced verdict block; throwaway shim under scripts/verify/<milestone>/p01-classify-one.sh as AD-19 single-script-file flat shape"
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P01/classifier-audit.md;scripts/verify/m028/p01-replay-coverage.sh;tmp/m028-p01/"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-29T11:42:49Z"
---

Replayed every M028 source event through the existing [M021](../../../../../milestones/M021/index.md) classifier (scripts/verify/lib/shape-classifier.sh, git SHA 12fcd98, last touched 2026-04-17) and recorded the verbatim verdict in [.orchestrator/milestones/M028/phases/P01/classifier-audit.md](../../../../../milestones/M028/phases/P01/classifier-audit.md). Source-event count is 9 (one per Finding A bbt-companion non-firing class, four Finding B shapes, Finding C investigation chain, Finding D rm+ls, Finding F operator-reported Stop-hook adapter+installer event, Finding G xargs sh -c body-descent). Of the 9 SEs, two reject under the live classifier as compound-chain-gt2 (SE-06 Finding C and SE-09 Finding G) — both anchored on AP-009 in the audit; four classify as allow (SE-02..SE-05 Finding B), confirming the spec's narration that AP-010..AP-014 reservations close real gaps; one classifies as allow (SE-07 Finding D) and the spec already documents the gap as Claude-Code-shape-independent destructive-op prompting; two are non-classifier events (SE-01 Finding A hook-never-invoked, SE-08 Finding F adapter+installer). The verifier scripts/verify/m028/p01-replay-coverage.sh exits 0 with 'PASS: classifier-audit.md has 9 source events, AP-009 anchor present'. T01 is fact-only per its task plan; T03 owns root-cause attribution and the collapse-vs-full-milestone recommendation, and consumes this audit as input evidence.

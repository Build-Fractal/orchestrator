---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M012"
provides:
  - "scripts/wiki/wiki-scan-sources.sh — single-source-of-truth scanner enumerating in-scope .orchestrator/**.md artifacts and printing <category>|<rel-path>|<title> records to stdout with exclusion policy enforced (scratch/, tmp/, config/, PLANNING-PAYLOAD, VERIFICATION, AGENTS.md, milestone/archive README.md, non-.md)"
requires:
  - "from:T01 what:wiki/ skeleton exists (stable target for downstream writers); from:none what:populated .orchestrator/ tree (constitution, DECISIONS.md, KNOWLEDGE.md, milestone-summary.md, milestones/M###/, archive/)"
affects:
  - "P01/T03 (wiki-generate-stubs consumes scanner stdout to emit thin include stubs), P01/T04 (wiki-generate-nav consumes scanner stdout to build nav block), P01/T05 (m012-p01-exclusion-policy.sh verifies scanner output)"
key_files:
  - "scripts/wiki/wiki-scan-sources.sh"
key_decisions:
  - "AD-3,AD-4,AD-19,FR-8"
patterns_established:
  - "single-source-of-truth scanner as emitter-internal helper (MEM004 carve-out — pipes/awk/find permitted since not agent-facing); scan-order discipline emits top-level artifacts, then milestones (lexical M###), then archive, with within-milestone lexical order for stable downstream consumption; title sanitization replaces pipe characters to preserve the 3-field schema invariant; /tmp list file (outside ROOT) avoids |-while subshell so running counter stays accurate; exclusion policy implemented via case-match on first path segment plus basename pattern tests in a should_exclude helper; never copies .orchestrator/**.md content — only enumerates paths + extracts one H1 title per file (AD-3 / Constitution VI compliance)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P01/tasks/T02-PAYLOAD.md"
duration: "25"
verification_result: "pass"
completed_at: "2026-04-18T13:16:12Z"
---

Shipped scripts/wiki/wiki-scan-sources.sh — the single source of truth for wiki in-scope artifact enumeration. Bash 3.2 compliant (no associative arrays, mapfile, uppercase expansion, process substitution, or ampersand-redirect). Accepts --root PROJECT_ROOT (defaults to two levels up from the script). Emits <category>|<rel-path>|<title> records on stdout and a SUMMARY: N trailer on stderr. Categories: top:constitution, top:decisions, top:knowledge, top:milestone-summary, milestone:M###, archive:M###. Exclusion policy enforces FR-8 + M012-ROADMAP Boundary Map: rejects .orchestrator/scratch/**, tmp/**, config/**, any basename matching AGENTS.md or README.md under milestone/archive trees, any basename containing PLANNING-PAYLOAD or VERIFICATION (covers both P##- and M###- variants per T02 must-haves), and any non-.md file. Title extraction reads the first H1 line via grep -m 1 '^# ' with basename-minus-.md fallback; pipe characters in titles are replaced with slashes to preserve the 3-field schema. Scanner is read-only relative to ROOT — transient /tmp/wiki-scan-$$.list file is outside ROOT and auto-cleaned per milestone iteration. Smoke validation (via /tmp probe script): 943 in-scope records emitted; 7 category prefixes present (archive: empty because .orchestrator/archive/ currently has no M### subdirs, only handoffs/); zero scratch/tmp/config/PLANNING-PAYLOAD/VERIFICATION/AGENTS.md/milestone-tree-README.md leakage; zero non-.md paths; zero empty titles; all records exactly 3 fields (one pre-sanitization hit on an [M005](../../../../milestones/M005/index.md) task with |-bearing title fixed via tr); order check confirms top:* before milestone:* before archive:*; --root /nonexistent exits 1 with error; --root /tmp (no .orchestrator subdir) exits 0 with SUMMARY: 0 on stderr. No nav, no stubs, no verify scripts — those land in T03/T04/T05 per the plan.

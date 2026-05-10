# Attack Surface Analysis: Compression Grammar Contract

## Executive Summary

The compression-grammar contract attempts to establish parse-regression safety guardrails for a four-tier context compression pipeline. While the document demonstrates awareness of preservation requirements, it contains multiple fatal flaws that would allow silent data corruption once tier implementations land in P02-P05.

The contract suffers from three critical classes of vulnerabilities: (1) incomplete preservation pattern definitions that miss common edge cases, (2) a fundamentally unreliable tier3 LLM-preservation mechanism that relies on hope rather than enforcement, and (3) unvalidated composition modeling where per-tier savings assumptions may double-count overlapping tokens. These flaws collectively undermine the document's central claim of parse-regression safety.

**Most dangerous flaw**: Tier3's LLM summarization phase has no enforceable mechanism to ensure preserved patterns survive the transformation, despite claiming "byte-identical" preservation. This creates a silent corruption pathway that would only manifest in production when downstream tooling encounters mangled MEM IDs, file paths, or URLs.

## Threat Catalog

### Grammar Specification Vulnerabilities

**[THREAT-01: Undefined quoted-string grammar]** (severity: high)
- **Description**: The marker grammar ABNF references `quoted-string` in kvpair values but never defines it, making the grammar formally incomplete and unimplementable.
- **Attack vector**: Any kvpair value containing quotes, spaces, or special characters will be parsed inconsistently across implementations.
- **Evidence**: L67-75 define the ABNF but `quoted-string` appears undefined; MIT-04 in L384 acknowledges this as deferred P1 work.
- **Blast radius**: Marker parsing failures in downstream tooling, inconsistent compression detection.
- **Likelihood**: Certain - any real-world usage will encounter quoted values.

**[THREAT-02: Nested code fence corruption]** (severity: high)  
- **Description**: Code fence preservation pattern `^`{3,}[a-zA-Z0-9_-]*$` doesn't handle nested fences, allowing inner fence delimiters to be corrupted during compression.
- **Attack vector**: Documents containing markdown examples with nested code blocks (common in documentation).
- **Evidence**: L125 pattern definition; MIT-01 in L382 was addressed but only for 3+ backticks, not nesting semantics.
- **Blast radius**: Markdown rendering breaks, code examples become unparseable.
- **Likelihood**: Likely - nested code blocks appear frequently in technical documentation.

**[THREAT-03: File extension preservation gap]** (severity: medium)
- **Description**: Absolute/relative path patterns only preserve specific extensions (sh|md|yml|yaml|jsonl?|py|txt), missing common file types.
- **Attack vector**: References to `.json`, `.csv`, `.log`, `.xml`, `.sql` files get corrupted during compression.
- **Evidence**: L127-128 extension list; MIT-03 in L383 acknowledges missing extensions as P1 deferred work.
- **Blast radius**: Broken file references in documentation, corrupted path-based tooling instructions.
- **Likelihood**: Likely - diverse file types are common in technical projects.

### Preservation Mechanism Failures

**[THREAT-04: LLM preservation trust boundary violation]** (severity: critical)
- **Description**: Tier3 claims preserved patterns must appear "byte-identical, AT LEAST ONCE" but provides no mechanism to enforce this constraint on LLM outputs.
- **Attack vector**: LLM summarization naturally paraphrases or omits specific identifiers, URLs, file paths during content reduction.
- **Evidence**: L252-255 claim LLM must preserve patterns but L264-268 only specify failure-after-the-fact detection, not prevention.
- **Blast radius**: Silent corruption of critical identifiers, broken downstream tooling, undetectable until runtime failures.
- **Likelihood**: Certain - LLMs cannot be constrained to preserve arbitrary byte patterns during summarization.

**[THREAT-05: UTF-8 boundary corruption]** (severity: high)
- **Description**: Tier2's "protected_tail_ratio" operates on byte boundaries without UTF-8 character awareness, potentially cutting mid-character.
- **Attack vector**: Any protected tail boundary that falls within a multi-byte UTF-8 character sequence.
- **Evidence**: L230 specifies "byte-identical" tail preservation but L234-237 show no UTF-8 boundary handling.
- **Blast radius**: Corrupted unicode characters, invalid UTF-8 sequences breaking downstream parsers.
- **Likelihood**: Possible - depends on content composition and tail ratio settings.

**[THREAT-06: JSONL pattern false positives]** (severity: medium)
- **Description**: JSONL preservation pattern `{...}` inside "any language tag" fenced blocks creates false matches for non-JSON content.
- **Attack vector**: Code examples in bash/python blocks that contain brace-delimited syntax (shell parameter expansion, Python dictionaries as strings).
- **Evidence**: L131 pattern definition allows "any language tag" without content validation.
- **Blast radius**: Over-preservation of non-JSON content, reduced compression efficiency, potential parsing conflicts.
- **Likelihood**: Possible - brace syntax appears in many programming languages.

### Composition and Modeling Vulnerabilities  

**[THREAT-07: Double-counting savings overlap]** (severity: high)
- **Description**: Per-tier savings models may double-count tokens that multiple tiers would operate on, making the 35.08% aggregate ceiling optimistic.
- **Attack vector**: Filter drops knowledge entries that tier3 would also have summarized; tier2 head-drops content tier3 would have compressed.
- **Evidence**: L320-325 acknowledge overlap issues but L338-343 admit the composition model is unvalidated; MIT-07 defers sequential simulation as P1.
- **Blast radius**: Performance expectations unmet, SC-9 threshold (34.7%) potentially violated in practice.
- **Likelihood**: Likely - the probe methodology doesn't simulate actual tier sequencing.

**[THREAT-08: SC-9 threshold fragility]** (severity: medium)
- **Description**: The 34.7% success threshold depends on fragile assumptions about knowledge entry status distribution and operator configuration stability.
- **Attack vector**: Lower than expected superseded/experimental entry prevalence, operators raising protected_tail_ratio system-wide, workloads staying below Standard intensity.
- **Evidence**: L345-358 enumerate specific conditions that would break the floor threshold.
- **Blast radius**: Compression targets missed, performance degradation, user experience below expectations.
- **Likelihood**: Possible - assumptions are based on historical data that may not predict future distributions.

### Implementation and Operational Vulnerabilities

**[THREAT-09: Self-check mechanism unspecified]** (severity: high)
- **Description**: Preservation self-checks are mandated but the algorithmic implementation is not defined, allowing inconsistent or ineffective validation.
- **Attack vector**: Implementation teams build weak self-checks that miss edge cases or fail to detect corruption patterns.
- **Evidence**: L285-291 mandate self-checks but provide no implementation specification or validation requirements.
- **Blast radius**: Preservation violations go undetected, silent data corruption in production.
- **Likelihood**: Likely - unspecified interfaces tend to have inconsistent implementations.

**[THREAT-10: Marker injection spoofing]** (severity: low)
- **Description**: Malicious or accidental HTML comments matching the `<!-- compressed:tierN ... -->` pattern could confuse downstream tooling.
- **Attack vector**: User-generated content or documentation containing similar HTML comment patterns.
- **Evidence**: L62-69 marker format has no authentication or uniqueness guarantees.
- **Blast radius**: Compression detection false positives, debugging confusion, potential tooling bypass.
- **Likelihood**: Unlikely - requires specific comment syntax and malicious/accidental timing.

## Cascading Failures

### Scenario: LLM Preservation Cascade
- **Trigger**: Tier3 LLM summarization silently drops MEM IDs from Knowledge section during compression
- **Propagation**: Downstream orchestrator commands fail to find referenced MEM entries → verification tools report false negatives → workflow automation breaks → manual intervention required for routine operations
- **Terminal state**: Context compression becomes unreliable for knowledge-heavy workloads, forcing operators to disable tier3 and miss compression targets

### Scenario: UTF-8 Corruption Chain  
- **Trigger**: Tier2 protected_tail_ratio cuts mid-character in unicode-heavy content
- **Propagation**: Invalid UTF-8 sequences break markdown parsers → documentation rendering fails → automated tooling crashes on malformed input → error propagates through entire pipeline
- **Terminal state**: Compression pipeline becomes unusable for international content, requiring full rollback to pre-M018 behavior

### Scenario: Double-Counting Performance Failure
- **Trigger**: Actual tier overlap significantly higher than modeled, aggregate savings fall to ~22% instead of promised 35%
- **Propagation**: Performance targets missed → user complaints about slow response times → pressure to disable compression → loss of context window efficiency gains
- **Terminal state**: M018 features rolled back, context window pressure returns, project unable to scale to larger contexts

## Missing Safeguards

**Input validation framework absent**: No specification for validating input content before compression to detect potentially problematic patterns, malformed UTF-8, or edge case structures that could break tier assumptions.

**Rollback mechanism unspecified**: No defined procedure for detecting compression-induced failures in production and reverting to uncompressed payloads when preservation violations cause downstream breakage.

**Monitoring and observability gaps**: No metrics framework for tracking preservation violation rates, compression effectiveness over time, or early warning indicators of systematic compression failures.

**Implementation compliance testing**: No test suite specification or validation framework to ensure tier implementations actually conform to the preservation contracts before deployment.

**Graceful degradation policies**: No specification for what happens when multiple tiers fail simultaneously, or how the system should behave when compression becomes unreliable during high-load periods.

**Content type detection**: No mechanism for detecting content that shouldn't be compressed (binary data encoded in text, deeply nested structures, pathological cases) before applying transformations that could corrupt it.
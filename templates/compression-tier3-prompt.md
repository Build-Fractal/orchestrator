---
schema_version: "1.0"
type: compression-prompt
tier: 3
applies_to: ["dispatch-payload-section"]
preserves: [
  "frontmatter '---' fences",
  "code fences (3+ backticks)",
  "JSONL records (lines starting with '{')",
  "MEM identifiers (MEM\\d+)",
  "absolute and project-relative paths",
  "scaffold-placeholder markers ({{ ... }})",
  "URLs",
  "orchestrator command names (slash-prefixed `/orchestrator-*`, colon-form `orchestrator:*`, or namespaced `speckit.orchestrator.*` aliases) and other slash-command tokens",
  "in-band compression markers (<!-- compressed:tierN ... -->)"
]
---

# Tier 3 Compression Prompt — M018/P06

You are summarizing one section of a dispatch payload to fit a token budget while preserving load-bearing content.

## Input contract

The input is a single dispatch-payload section beginning with a markdown header line (`## <Section>`) and continuing through its body. The section may exceed the configured budget after Tier 1 microcompact + Tier 2 head-drop have already run.

## Output contract

Produce a summary that:

1. **Begins** with the original `## <Section>` header line, byte-identical.
2. **Immediately follows** the header with this in-band marker on its own line:
   ```
   <!-- compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M> -->
   ```
   The orchestrator post-processes the marker; emit it with placeholder values `<MODEL>`, `<N>`, `<M>` and the orchestrator will substitute them.
3. **Preserves verbatim** every byte that matches the patterns listed in this template's frontmatter `preserves:` array. Specifically:
   - Frontmatter `---` fence pairs and the lines between them.
   - Code fences (3 or more backticks) and the code lines between them.
   - JSONL records (lines starting with `{` and ending with `}`).
   - MEM identifiers (e.g., `MEM001`, `MEM031`).
   - Absolute and project-relative paths (e.g., `scripts/dispatch/build-context.sh`).
   - Scaffold-placeholder markers (e.g., `{{milestone_id}}`).
   - URLs (e.g., `https://example.com/path`).
   - Orchestrator command names — slash form (`/orchestrator-auto`), colon form (`orchestrator:auto`), or namespaced alias (`speckit.orchestrator.dispatch`).
   - In-band compression markers from earlier tiers.
4. **Compresses prose** between preserved patterns: paraphrase verbose narrative into terse bullet form; collapse redundant sentences; cite section / decision / MEM IDs rather than restating their content.
5. **Stays under** the output token budget named in the orchestrator's invocation. The orchestrator discards summaries that exceed `output_max_ratio` (default 0.80) of input bytes.

## Failure modes

If you cannot produce a summary that honors all four output-contract clauses (e.g., the input is mostly preserved patterns with no compressible prose), **return the input unchanged** with the original `## <Section>` header but no `<!-- compressed:tier3 ... -->` marker. The orchestrator detects the absent marker and treats the call as no-savings (passthrough).

## Section to compress

Replace this block with the input section. The orchestrator renders the prompt by appending the section bytes after this header.

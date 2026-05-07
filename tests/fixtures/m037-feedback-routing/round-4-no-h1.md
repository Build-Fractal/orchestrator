Synthetic test fixture exercising humanized-basename fallback.
No H1 heading; first line is body text.

extract_title in wiki-scan-sources.sh falls back to the basename
(round-4-no-h1) when no `# Heading` line is present, so the emitted
stub's title: frontmatter field is non-empty even with no H1.

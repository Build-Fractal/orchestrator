# Wiki URL Scheme (M012 addendum)

Addendum to M012 (`specs/022-spec-wiki/spec.md`). Pins the public URL scheme the dogfood wiki produces so downstream milestones (M013 `orchestrator:github` custom-field links; M014 comment router; future launch docs) can consume stable URLs without reinventing the mapping.

This addendum does not change what M012 ships. It formalizes the routing the M012 pipeline already produces.

## Base URL

- **Production GitHub Pages**: `https://<github-org>.github.io/<repo>/` (the default for a `gh-deploy`d repo Pages site). For this repo, that resolves to `https://lakeledger.github.io/orchestrator/` once the operator performs the M012 first deploy and flips `wiki/mkdocs.yml`'s placeholder `site_url` (`https://example.invalid/`) to the real value.
- **Local preview**: `http://127.0.0.1:8000/` (default for `scripts/wiki/wiki-serve.sh` → `mkdocs serve`). Paths below are suffixes of the base URL in both cases.

## Path routing

MkDocs is run with its default `use_directory_urls: true`. Every `wiki/docs/<path>.md` renders to a rendered route at `<base>/<path>/` (trailing slash, no `.md`, no `.html`). `wiki/docs/index.md` renders to `<base>/`.

The M012 `scripts/wiki/` pipeline produces stubs at paths that mirror the canonical source:

| Source | Stub path | Rendered URL |
|---|---|---|
| `.orchestrator/memory/constitution.md` | `wiki/docs/constitution.md` | `<base>/constitution/` |
| `.orchestrator/DECISIONS.md` | `wiki/docs/decisions.md` | `<base>/decisions/` |
| `.orchestrator/KNOWLEDGE.md` | `wiki/docs/knowledge.md` | `<base>/knowledge/` |
| `.orchestrator/milestone-summary.md` | `wiki/docs/milestone-summary.md` | `<base>/milestone-summary/` |
| `.orchestrator/milestones/M012/M012-SUMMARY.md` | `wiki/docs/milestones/M012/M012-SUMMARY.md` | `<base>/milestones/M012/M012-SUMMARY/` |
| `.orchestrator/milestones/M012/phases/P04/P04-SUMMARY.md` | `wiki/docs/milestones/M012/phases/P04/P04-SUMMARY.md` | `<base>/milestones/M012/phases/P04/P04-SUMMARY/` |
| `knowledge/patterns/MEM001.md` | `wiki/docs/knowledge/patterns/MEM001.md` | `<base>/knowledge/patterns/MEM001/` |

The pattern is: `<base>/<stub-path-without-.md-extension>/`. Directory `index.md` files drop their filename (e.g., `wiki/docs/milestones/M012/index.md` → `<base>/milestones/M012/`).

## URL stability guarantees

- **Pathname mapping** is the chosen Giscus thread key (AD-5; documented in `wiki/README.md` "## Giscus mapping"). A rendered URL is the thread identity. Renaming a source artifact renames its rendered URL and therefore orphans its thread — `scripts/diagnostics/wiki-giscus-remap.sh` is the remap path.
- **Within a milestone directory**, URLs are stable. Consolidation (`orchestrator:consolidate`) moves artifacts from `.orchestrator/milestones/M<xxx>/` to `.orchestrator/archive/M<xxx>/` — this is a deliberate URL rename. Run the remap script before the consolidation commit lands.
- **Trailing slash is load-bearing.** `<base>/constitution` (no slash) is a redirect, not the canonical URL. Consumers that key on URL identity should normalize to the trailing-slash form.
- **Case sensitivity** follows the source filename. `M012` not `m012`.

## SPEC chunk URLs (not yet surfaced — M013 scope decision)

The scanner (`scripts/wiki/wiki-scan-sources.sh`) today emits records for:

1. `.orchestrator/**.md` (filtered per the documented exclusion policy)
2. `knowledge/{patterns,conventions,lessons}/MEM*.md`

It does **not** scan `knowledge/spec/{acceptance,constraint,nfr,non-goal,requirement,story}/SPEC-*.md`. SPEC chunks are therefore not currently surfaced on the wiki. Any URL of the form `<base>/knowledge/spec/story/SPEC-US-001/` is aspirational until the scanner is extended.

M013 depends on stable SPEC chunk URLs (FR-3: "spec chunk ↔ custom field on the Issue whose value is the chunk's wiki URL"). M013 planning chooses one of:

1. **Widen M012's scanner** to additively emit `knowledge:spec:<category>` records — stubs at `wiki/docs/knowledge/spec/<category>/SPEC-<id>.md`, rendered at `<base>/knowledge/spec/<category>/SPEC-<id>/`. Follows M012's additive-extension invariant; lands as an M013/P01 task.
2. **Link to the GitHub source** at `https://github.com/<org>/<repo>/blob/main/knowledge/spec/<category>/SPEC-<id>.md`. Zero wiki work; loses in-wiki navigation for stakeholders.
3. **Ship SPEC chunks as a parallel M013 wiki surface** (separate stub tree under `wiki/docs/specs/`) — larger scope; only warranted if SPEC surfacing diverges materially from MEM surfacing.

The pending-sentinel convention applies: until M013 picks, M013 sync can write the GitHub-source URL (option 2) as a deterministic fallback rather than block on the decision.

## Operator actions at first deploy

1. Set `site_url` in `wiki/mkdocs.yml` to the real Pages URL (replacing `https://example.invalid/`).
2. Run `scripts/wiki/wiki-deploy.sh` end-to-end per `wiki/README.md` "## Running the deploy wrapper".
3. After deploy, smoke-check a representative set of URLs against this addendum. Flag any divergence as a bug against the M012 pipeline, not against this scheme.
4. Update `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` with the live `deployed_url` (replacing the `pending` sentinel).

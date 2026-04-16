# M015 P04 Spec-Kit Migration Fixture

Deterministic minimal spec-kit-shaped project tree used by T02 to
validate that `scripts/migrate/migrate.sh` produces a valid
`.orchestrator/` directory when run against a spec-kit-shaped source.

The fixture tree itself is NOT committed — it is generated on demand
by `build-fixture.sh` into a caller-supplied directory. This follows
the precedent of `tests/fixtures/m003-p08-gsd-minimal/build-fixture.sh`.

## Usage

```bash
# T02 invokes this pattern:
TMP=$(mktemp -d)
bash tests/fixtures/m015-p04-speckit-migration/build-fixture.sh "$TMP"
# Then: bash scripts/migrate/migrate.sh --source "$TMP" ... (see T02 plan)
```

## Produced Tree

```
<target-dir>/
  .specify/
    memory/
      constitution.md         # minimal 7-principle stub
  specs/
    001-example/
      spec.md                 # minimal spec with frontmatter
  README.md                   # project README sentinel
```

## Why spec-kit-shaped

The orchestrator retained spec-kit as a **migration source** (FR-013).
This fixture exists because the cutover removed spec-kit as a
**runtime host** but preserved the ability for users coming *from*
spec-kit to migrate into the orchestrator. Every run proves that
path still works end-to-end.

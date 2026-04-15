# tests/

Integration test suites for the orchestrator extension. 7 suites, 294 total assertions.

## Running Tests
```bash
# All suites
for f in tests/test-s*.sh; do bash "$f"; done

# Individual suite
bash tests/test-s02-state-machine.sh
```

## Conventions
- `pass()`/`fail()` functions with parallel indexed arrays (bash 3.2 compatible)
- Structured `PASS:`/`FAIL:` output with summary count
- Exit 0 = all pass, exit 1 = any failure
- Fixtures in `tests/fixtures/` — named by scenario

## Suites
| File | Assertions | Covers |
|------|-----------|--------|
| test-s01-structure.sh | 11 | Directory tree, config template |
| test-s02-state-machine.sh | 23 | 9 state derivations, config resolution, roadmap parsing, scaffolding |
| test-s03-design-artifacts.sh | 60 | 13 templates + 4 reference docs structural validation |
| test-s04-core-commands.sh | 51 | Verification scripts, dispatch scripts, 6 command files |
| test-s05-autonomous-mode.sh | 61 | Lifecycle scripts (lock, stuck, recovery, budget), auto/resume/discuss commands |
| test-s06-knowledge-lifecycle.sh | 57 | Knowledge scripts, rollback, consolidation, consolidate command |
| test-s07-integration.sh | 22 | Cross-slice manifest alignment, cross-references, capabilities, diagnostics |

## Fixture Directory
Fixtures are minimal file trees that trigger specific states or scenarios. Key patterns:
- `state-*` directories: one per state derivation result (9 total)
- `verify-pass`/`verify-fail`/`verify-scope`: verification scenarios
- `dispatch-state`: complete milestone tree for context assembly testing
- `auto-*`: lock, stuck, recovery, budget scenario fixtures
- `knowledge-*`, `rollback-*`, `consolidate-*`: knowledge/lifecycle fixtures

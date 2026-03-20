| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01/T01 | arch | State derivation mechanism? | File-presence-based | Crash recovery derives state from what exists | No |
| D002 | M001/P01/T02 | convention | Shell script portability target? | POSIX sh | Must work on macOS and Linux | Yes — if we drop macOS support |
| D003 | M001/P02/T01 | pattern | Verification tier model? | 4-tier ladder | Matches research from GSD-2 and APM | No |

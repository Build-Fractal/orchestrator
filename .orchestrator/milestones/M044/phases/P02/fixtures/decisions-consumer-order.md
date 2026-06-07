| # | Decision | Choice | Scope | When | Rationale | Revisable? |
|---|----------|--------|-------|------|-----------|------------|
| D001 | Index demoted to cache? | Yes, grep is the guarantee | arch | M044/P01 | Silent degradation is the enemy | No |
| D002 | Stale detection mechanism? | mtime delta | pattern | M044/P02 | Cheapest check, no full corpus read | Yes |
| D003 | Unrelated milestone decision | Some choice | arch | M099/P01 | Out of scope for M044 | Yes |

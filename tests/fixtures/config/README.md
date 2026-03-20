# Config Resolution Test Fixtures

## Precedence Order (highest → lowest)

1. **Environment variables** (`SPECKIT_ORCHESTRATOR_*`) — highest precedence
2. **Local config** (`orchestrator-config.local.yml`) — per-developer overrides
3. **Project config** (`orchestrator-config.yml`) — team-shared settings
4. **Extension defaults** (extension.yml `defaults` section) — factory values

## Expected Resolution per Key

| Key | Ext Default | Project | Local | Env Var | Winner (no env) | Winner (with env) |
|-----|-------------|---------|-------|---------|-----------------|-------------------|
| `default_tier` | `null` | — | — | `SPECKIT_ORCHESTRATOR_DEFAULT_TIER=B` | `null` | `B` |
| `verification_commands` | `[]` | — | — | — | `[]` | `[]` |
| `context_verbosity` | `standard` | `full` | `minimal` | — | `minimal` | `minimal` |
| `git_isolation` | `false` | `true` | — | — | `true` | `true` |
| `dispatch_budget` | `null` | — | — | — | `null` | `null` |
| `duration_budget` | `null` | — | — | — | `null` | `null` |
| `budget_enforcement` | `advisory` | — | — | — | `advisory` | `advisory` |

## How to Use

The test harness calls `read-config.sh` with these fixture files to verify that:
1. Extension defaults apply when no overrides exist
2. Project config overrides extension defaults
3. Local config overrides project config
4. Environment variables override everything

# Scope fixture: specs-like file WITHOUT the agent-facing marker

This file represents a file under specs/, references/, or docs/ that does NOT
opt into linter scanning. The bash fence below trips a Class A detector if the
linter sees it, but the linter should never see it when sweeping default roots.

```bash
bash scripts/foo.sh --at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

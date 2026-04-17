# Scope fixture: specs-like file WITH the agent-facing marker

<!-- agent-facing -->

This file represents a file under specs/, references/, or docs/ that DOES opt
into linter scanning via the marker above. The bash fence below trips a Class A
detector and the linter should flag it when the file is scoped in.

```bash
bash scripts/foo.sh --at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

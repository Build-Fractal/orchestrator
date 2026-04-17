# Class A fixture: command substitution

Minimal bash fence containing $(...) — expected to trip AP-004.

```bash
bash scripts/foo.sh --completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

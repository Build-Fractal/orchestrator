<!-- M018/P02 Knowledge baseline (compression.enabled:false short-circuit) -->
---
id: MEM900
scope_tags: "[project]"
category: patterns
confidence: 0.95
created_at: 2026-04-27
last_verified: 2026-04-27
hit_count: 1
source_unit: "M018/P02"
source_type: fixture
status: stable
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM900: Stable Reference Pattern

This is a stable, fixture-only entry used to exercise the M018/P02 knowledge
filter. Its `status: stable` field means it should never be dropped by the
default drop-list (`["superseded", "experimental"]`).

The filter operates on whole-entry granularity per grammar contract
`## Tier: filter` failure semantics — there is no preserved-pattern
self-check at the entry interior.

---
id: MEM901
scope_tags: "[project]"
category: patterns
confidence: 0.40
created_at: 2026-04-27
last_verified: 2026-04-27
hit_count: 1
source_unit: "M018/P02"
source_type: fixture
status: superseded
supersedes: ""
superseded_by: "MEM900"
relates_to: []
content_hash: ""
---

# MEM901: Superseded Pattern (legacy)

This entry is `status: superseded` — the M018/P02 default drop-list
includes "superseded", so this entry MUST be dropped from dispatch payloads
when the filter is enabled.

This body exists to give the filter something to byte-count: the
`dropped_tokens` field on the `payload_filter` JSONL record is the
quartile-rounded char count of dropped entries' total bytes.

---
id: MEM902
scope_tags: "[project]"
category: patterns
confidence: 0.85
created_at: 2026-04-27
last_verified: 2026-04-27
hit_count: 1
source_unit: "M018/P02"
source_type: fixture
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM902: Pre-M020 Entry (no status field)

This entry has NO `status:` field in its frontmatter — emulating the bulk
of pre-M020 knowledge entries. Per FR-3 + grammar contract `## Tier:
filter` failure semantics, missing `status:` defaults to RETAINED.

The rule is fail-open: an entry with no status field can never be
silently dropped, even if a future drop-list is misconfigured.

---
id: MEM903
scope_tags: "[project]"
category: lessons
confidence: 0.30
created_at: 2026-04-27
last_verified: 2026-04-27
hit_count: 1
source_unit: "M018/P02"
source_type: fixture
status: experimental
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM903: Experimental Pattern (under evaluation)

This entry is `status: experimental`. The default drop-list includes
"experimental", so this entry MUST be dropped from dispatch payloads when
the filter is enabled.

Experimental status is the second category in the default drop-list. Spec
acceptance scenario 2: drop two entries, retain three.

---
id: MEM904
scope_tags: "[project]"
category: conventions
confidence: 0.95
created_at: 2026-04-27
last_verified: 2026-04-27
hit_count: 1
source_unit: "M018/P02"
source_type: fixture
status: graduated
supersedes: ""
superseded_by: ""
relates_to: []
content_hash: ""
---

# MEM904: Graduated Pattern (M020-aware)

This entry carries `status: graduated`. The M018/P02 default drop-list
does NOT include "graduated" — per MEM031, pre-M020 entries default to
graduated when annotated. Graduated entries are always retained.

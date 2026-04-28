# Dispatch Context -- T01 (Phase P04, Milestone M018-fixture)

## Manifest

| Section | Lines | Tokens |
|---------|-------|--------|
| Upstream Context | 60 | 400 |

## Knowledge

Empty knowledge — this fixture exercises Upstream Context, not Knowledge.

## Decisions

No decision entries in scope.

## Upstream Context

Leading prose paragraph one. The Upstream Context section is the in-scope target for boundary refusal. We want the naive cut byte at floor(body_chars * 0.7) to land inside a 4-backtick code fence that opens above the cut and closes inside the protected tail.

Leading prose paragraph two. More byte filler so the body has plenty of head bytes to nominally drop. The cut byte should land between the fence opener and fence closer when budget is 200 tokens; the walker must then retreat above the fence opener.

Leading prose paragraph three. Final pre-fence prose. Below this paragraph the 4-backtick fence opens; everything inside the fence must be kept intact because the fence closer lives in the protected tail and the snip cannot orphan the fence opener.

````bash
# four-backtick fence opens here — note the four leading backticks
print "boundary-refusal-fence-content marker line one"
print "boundary-refusal-fence-content marker line two"
print "boundary-refusal-fence-content marker line three"
```nested-three-backtick-fence
print "this 3-tick line must NOT close the outer 4-tick fence (MIT-01)"
```
print "boundary-refusal-fence-content marker line four"
print "boundary-refusal-fence-content marker line five"
print "boundary-refusal-fence-content marker line six"
print "boundary-refusal-fence-content marker line seven"
print "boundary-refusal-fence-content marker line eight"
print "boundary-refusal-fence-content marker line nine"
print "boundary-refusal-fence-content marker line ten"
print "boundary-refusal-fence-content marker line eleven"
print "boundary-refusal-fence-content marker line twelve"
````

Trailing prose paragraph one. The fence closes above this line — the closer is the matching 4-backtick row. The protected tail of the section extends from somewhere inside the fence body through this trailing prose.

Trailing prose paragraph two. More tail bytes so the protected_tail_ratio of 0.3 has room to land. The verifier reads the post-snip output and checks the fence opener and fence closer are both unaltered.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M018-fixture"
---

Stub task body.

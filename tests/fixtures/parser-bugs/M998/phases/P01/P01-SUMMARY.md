---
id: P01
parent: M998
key_files:
  - "tests/fixtures/parser-bugs/M998/sample.txt (modified, secondary edit), tests/fixtures/parser-bugs/M998/sibling.txt (touched, additional context)"
---

P01 phase summary with parenthetical commentary inside key_files. The naive
splitter (IFS=',;') would tokenize the inner commas and produce bogus path
fragments like "secondary edit)" that fail filesystem-existence checks even
though sample.txt and sibling.txt both exist.

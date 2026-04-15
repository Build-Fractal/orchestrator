-- =============================================================================
-- seed.sql — Synthetic minimal GSD2 fixture for M003/P08 end-to-end test
-- =============================================================================
--
-- Generates a deterministic gsd.db that exercises every extract_* branch in
-- the GSD2 adapter (scripts/migrate/adapters/gsd2.sh + lib/sqlite-reader.sh):
--
--   memories              -> extract_knowledge
--   decisions             -> extract_decisions
--   requirements          -> extract_requirements
--   milestones            -> extract_milestones
--   slices                -> extract_milestones
--   tasks                 -> extract_milestones
--   verification_evidence -> extract_telemetry
--
-- All timestamps are hard-coded (no datetime('now')) so the resulting
-- gsd.db is byte-identical across builds on the same machine. Content is
-- wholly synthetic — no private data from any real project.
-- =============================================================================

PRAGMA page_size = 1024;
PRAGMA foreign_keys = OFF;

-- -----------------------------------------------------------------------------
-- memories
-- -----------------------------------------------------------------------------
CREATE TABLE memories (
    id TEXT PRIMARY KEY,
    seq INTEGER,
    category TEXT,
    content TEXT,
    source_unit_id TEXT,
    confidence REAL,
    hit_count INTEGER,
    created_at TEXT,
    updated_at TEXT,
    superseded_by TEXT
);

INSERT INTO memories VALUES
    ('MEM001', 1, 'pattern',
     'Bash 3.2 compatibility is mandatory. Use parallel indexed arrays instead of associative arrays (declare -A).',
     'M001/S01', 0.95, 7, '2025-06-01T00:00:00Z', '2025-06-01T00:00:00Z', NULL),
    ('MEM002', 2, 'pattern',
     'YAML parsing uses grep/sed/awk only. Scripts emit prefixed lines (PASS:, FAIL:, LOCK:) to stdout; errors to stderr.',
     'M001/S01', 0.90, 5, '2025-06-02T00:00:00Z', '2025-06-02T00:00:00Z', NULL),
    ('MEM003', 3, 'gotcha',
     'macOS tr does not support \x hex escapes. Use printf ''\002'' + sed substitution instead of tr for STX placeholder.',
     'M001/S02', 0.85, 3, '2025-06-03T00:00:00Z', '2025-06-03T00:00:00Z', NULL),
    ('MEM004', 4, 'gotcha',
     'sqlite3 separator must avoid bytes that appear in user content. Use ASCII Unit Separator (0x1F) not tab or pipe.',
     'M001/S02', 0.80, 2, '2025-06-04T00:00:00Z', '2025-06-04T00:00:00Z', NULL);

-- -----------------------------------------------------------------------------
-- decisions
-- -----------------------------------------------------------------------------
CREATE TABLE decisions (
    id TEXT PRIMARY KEY,
    seq INTEGER,
    decision TEXT,
    scope TEXT,
    when_context TEXT,
    choice TEXT,
    rationale TEXT,
    revisable TEXT,
    made_by TEXT,
    superseded_by TEXT
);

INSERT INTO decisions VALUES
    ('AD-001', 1,
     'Use SQLite as primary source of truth',
     'project', '2025-06-01T00:00:00Z',
     'SQLite gsd.db',
     'Binary format is deterministic, queryable, and survives concurrent writers with WAL.',
     'yes', 'human', NULL),
    ('AD-002', 2,
     'Commit pre-built gsd.db alongside seed.sql',
     'testing', '2025-06-02T00:00:00Z',
     'Commit both',
     'Fast CI startup (no sqlite3 build step) plus reproducibility from seed when regenerating.',
     'yes', 'human', NULL);

-- -----------------------------------------------------------------------------
-- requirements
-- -----------------------------------------------------------------------------
CREATE TABLE requirements (
    id TEXT PRIMARY KEY,
    class TEXT,
    status TEXT,
    description TEXT,
    validation TEXT,
    source TEXT,
    supporting_slices TEXT,
    primary_owner TEXT,
    superseded_by TEXT
);

INSERT INTO requirements VALUES
    ('R001', 'functional', 'active',
     'Migration pipeline MUST emit non-zero counts for every content category when run against a non-empty GSD2 fixture.',
     'bash scripts/migrate/migrate.sh ... && grep -qE ''^- [1-9]'' MIGRATION-REPORT.md',
     'M003/P08', 'M001/S01', 'platform', NULL),
    ('R002', 'non-functional', 'active',
     'Fixture gsd.db MUST be under 50 KB and reproducible from seed.sql on the same machine.',
     'wc -c .gsd/gsd.db | awk ''{exit ($1 < 51200) ? 0 : 1}''',
     'M003/P08', 'M001/S01', 'platform', NULL);

-- -----------------------------------------------------------------------------
-- milestones
-- -----------------------------------------------------------------------------
CREATE TABLE milestones (
    id TEXT PRIMARY KEY,
    title TEXT,
    status TEXT,
    vision TEXT,
    created_at TEXT,
    completed_at TEXT
);

INSERT INTO milestones VALUES
    ('M001', 'Foundation', 'completed',
     'Ship the minimal backbone: state machine, scripts, template set, single-agent validation.',
     '2025-05-01T00:00:00Z', '2025-06-30T00:00:00Z'),
    ('M002', 'Migration', 'active',
     'Land the migration pipeline so existing GSD2 projects can onboard without manual remediation.',
     '2025-07-01T00:00:00Z', NULL);

-- -----------------------------------------------------------------------------
-- slices
-- -----------------------------------------------------------------------------
CREATE TABLE slices (
    id TEXT PRIMARY KEY,
    milestone_id TEXT,
    title TEXT,
    status TEXT,
    goal TEXT,
    sequence INTEGER
);

INSERT INTO slices VALUES
    ('M001/S01', 'M001', 'Scripts and state machine', 'completed',
     'Ship the derive-phase / record-result / dispatch surface with Bash 3.2 conventions.', 1),
    ('M001/S02', 'M001', 'Verification ladder', 'completed',
     'Four-tier verify: static, command, behavioral, human. Run-verify wires all four.', 2),
    ('M002/S01', 'M002', 'GSD2 adapter', 'active',
     'Adapter reads SQLite, falls back to JSON, then to filesystem scan of milestone dirs.', 1);

-- -----------------------------------------------------------------------------
-- tasks
-- -----------------------------------------------------------------------------
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    slice_id TEXT,
    milestone_id TEXT,
    title TEXT,
    status TEXT,
    description TEXT
);

INSERT INTO tasks VALUES
    ('T001', 'M001/S01', 'M001', 'Write derive-phase.sh', 'completed',
     'State derivation from on-disk file presence, priority-ordered rules, 9 states covered.'),
    ('T002', 'M001/S02', 'M001', 'Wire run-verify.sh', 'completed',
     'Four-tier verification ladder with structured output and audit trail.'),
    ('T003', 'M002/S01', 'M002', 'Ship SQLite reader', 'active',
     'ASCII Unit Separator delimiting, STX newline placeholder, Bash 3.2 safe splitting.');

-- -----------------------------------------------------------------------------
-- verification_evidence
-- -----------------------------------------------------------------------------
CREATE TABLE verification_evidence (
    id INTEGER PRIMARY KEY,
    created_at TEXT,
    verdict TEXT,
    task_id TEXT,
    milestone_id TEXT,
    slice_id TEXT,
    command TEXT,
    exit_code INTEGER,
    duration_ms INTEGER
);

INSERT INTO verification_evidence VALUES
    (1, '2025-06-15T12:00:00Z', 'pass', 'T001', 'M001', 'M001/S01',
     'bash tests/test-derive-phase.sh', 0, 820),
    (2, '2025-06-20T12:00:00Z', 'pass', 'T002', 'M001', 'M001/S02',
     'bash tests/test-run-verify.sh', 0, 1240),
    (3, '2025-07-10T12:00:00Z', 'pass', 'T003', 'M002', 'M002/S01',
     'bash tests/test-sqlite-reader.sh', 0, 510);

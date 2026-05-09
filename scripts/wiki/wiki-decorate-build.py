#!/usr/bin/env python3
"""
wiki-decorate-build.py — full-tree wiki readability decorator.

Walks every wiki stub that includes from .orchestrator/ or knowledge/,
decorates the included markdown into wiki/.staged/, rewrites the stub to
include from .staged/ with rewrite-relative-urls=false, and (when a
sibling <stub>.summary.md exists) prepends a Material `!!! info "In plain
English"` admonition.

Behaviors:
  1. Walks wiki/docs/**/*.md for stubs that contain
     `include-markdown ".../<.orchestrator|knowledge>/<rel>.md"`.
  2. Decorates the source markdown:
       - hyperlinks every known DR-/AN-/BG-/OD-/etc. code with a
         hover-tooltip title;
       - hyperlinks every bare `.orchestrator/<rest>.md` reference;
       - hyperlinks `§N[.N…]` tokens that appear near an
         `.orchestrator/<file>.md` reference (within ~80 chars) when the
         target file has a heading whose number prefix matches;
       - hyperlinks bare milestone names (M\\d{3}, M2a-min, M-Spike-A,
         …) on first occurrence per page when a matching milestone dir
         exists at wiki/docs/milestones/<name>/.
  3. Writes the decorated copy to wiki/.staged/<same-relative-path>.
  4. Rewrites the stub's include-markdown directive to pull from .staged/
     with rewrite-relative-urls=false.
  5. If a sibling <stub>.summary.md exists in wiki/docs/, prepends an
     `!!! info "In plain English"` admonition wrapping it (idempotent).
  6. After writing each staged file, touches the stub mtime so
     `mkdocs serve` rebuilds (mkdocs only watches docs_dir).
  7. Idempotent + mtime-skip: re-running with no source changes is a no-op.
  8. Emits /tmp/wiki-summary-todo.md listing stubs without summaries.

Source-of-truth inputs:
  .orchestrator/DECISIONS.md          (### CODE — Title, plus bullet shapes)
  Project-configured spec markdown(s) (| CODE | Title | …) — see
                                      .orchestrator/config.yml wiki: keys.

Configuration (.orchestrator/config.yml, wiki: namespace):
  wiki:
    code_prefixes: [AN, BG, OD]      # spec-table code prefixes to scan
    spec_paths:                      # .orchestrator-relative spec markdown(s)
      - spec/<plan>.md

  Both keys default to empty lists. With empty lists the decorator still
  runs against DECISIONS.md alone — zero-config-friendly for projects
  without a pipe-table-coded spec.

Wiki paths follow the M012 convention: every .orchestrator/<rest>.md
renders as wiki stub at wiki/docs/<rest>.md.

Usage:
    python3 scripts/wiki/wiki-decorate-build.py
    python3 scripts/wiki/wiki-decorate-build.py --force
    python3 scripts/wiki/wiki-decorate-build.py --print-map
    python3 scripts/wiki/wiki-decorate-build.py --only milestones/<name>/<NAME>-CONTEXT.md
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# Module-level paths default to the script's own repo. main() rebinds
# them when --root is passed (used by wiki-stubs-fresh.sh against a
# staged tmp tree).
REPO_ROOT = Path(__file__).resolve().parents[2]
ORCH = REPO_ROOT / ".orchestrator"
DECISIONS = ORCH / "DECISIONS.md"
WIKI_DIR = REPO_ROOT / "wiki"
WIKI_DOCS = WIKI_DIR / "docs"
WIKI_STAGED = WIKI_DIR / ".staged"
SUMMARY_TODO = Path("/tmp/wiki-summary-todo.md")

# Populated by load_wiki_config(); generic shape so the decorator runs
# against any orchestrator-managed project. Defaults are empty lists so
# the decorator still operates (DECISIONS.md decoration only) when the
# project has not opted in.
CODE_PREFIXES: tuple[str, ...] = ()
SPEC_PATHS: tuple[Path, ...] = ()


def _rebind_paths(root: Path) -> None:
    global REPO_ROOT, ORCH, DECISIONS, WIKI_DIR, WIKI_DOCS, WIKI_STAGED
    REPO_ROOT = root
    ORCH = REPO_ROOT / ".orchestrator"
    DECISIONS = ORCH / "DECISIONS.md"
    WIKI_DIR = REPO_ROOT / "wiki"
    WIKI_DOCS = WIKI_DIR / "docs"
    WIKI_STAGED = WIKI_DIR / ".staged"


# ---------- config loader ----------

# Minimal line-oriented YAML reader for the two keys we need under wiki:.
# Avoids the PyYAML hard-dep — PyYAML is treated as optional across the
# orchestrator scripts (see scripts/verify/m013-p01-uat-template.sh and
# scripts/dispatch/adapters/tool/conversus.sh). We only read scalars +
# inline-list / block-list shapes; nothing else under wiki: matters here.

_INLINE_LIST_RX = re.compile(r"^\s*\[(.*)\]\s*$")
_BLOCK_LIST_ITEM_RX = re.compile(r"^\s*-\s+(.+?)\s*$")


def _strip_yaml_scalar(s: str) -> str:
    s = s.strip()
    if (s.startswith('"') and s.endswith('"')) or (
        s.startswith("'") and s.endswith("'")
    ):
        s = s[1:-1]
    return s


def _parse_inline_list(body: str) -> list[str]:
    return [
        _strip_yaml_scalar(item)
        for item in body.split(",")
        if item.strip() != ""
    ]


def _read_wiki_block(cfg_text: str) -> dict[str, object]:
    """Return a flat dict of wiki.<key> → value (str or list[str]).

    Recognised shapes:
      wiki:
        code_prefixes: [AN, BG, OD]
        spec_paths:
          - spec/foo.md
          - spec/bar.md
      wiki.code_prefixes: [AN, BG, OD]
      wiki.spec_paths: [spec/foo.md]
    """
    out: dict[str, object] = {}
    lines = cfg_text.splitlines()
    in_wiki = False
    wiki_indent: int | None = None
    pending_list_key: str | None = None
    pending_list_indent: int | None = None
    pending_list: list[str] = []

    def _flush_pending() -> None:
        nonlocal pending_list_key, pending_list_indent, pending_list
        if pending_list_key is not None:
            out[pending_list_key] = list(pending_list)
        pending_list_key = None
        pending_list_indent = None
        pending_list = []

    for raw in lines:
        # Strip trailing comments (very conservative — only `#` preceded
        # by whitespace; YAML allows # in quoted strings, but our schema
        # never uses them).
        line = re.sub(r"\s+#.*$", "", raw).rstrip()
        if line.strip() == "" or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))

        # Inline `wiki.<key>:` form lives at any indent and is self-contained.
        m_inline_dotted = re.match(
            r"^\s*wiki\.([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line
        )
        if m_inline_dotted:
            _flush_pending()
            key = m_inline_dotted.group(1)
            rest = m_inline_dotted.group(2).strip()
            m_list = _INLINE_LIST_RX.match(rest)
            if m_list:
                out[key] = _parse_inline_list(m_list.group(1))
            elif rest == "":
                # Empty scalar — treat as empty list for our two keys.
                out[key] = []
            else:
                out[key] = _strip_yaml_scalar(rest)
            continue

        # Top-level `wiki:` block opener.
        if re.match(r"^wiki\s*:\s*$", line):
            _flush_pending()
            in_wiki = True
            wiki_indent = indent
            continue
        # Inline `wiki: { ... }` — out of scope; skip.
        if re.match(r"^wiki\s*:\s*\{", line):
            _flush_pending()
            in_wiki = False
            continue

        if in_wiki:
            # If we're collecting a block list and the next line is a
            # `- item`, accumulate.
            if (
                pending_list_key is not None
                and pending_list_indent is not None
                and indent >= pending_list_indent
            ):
                m_item = _BLOCK_LIST_ITEM_RX.match(line)
                if m_item:
                    pending_list.append(_strip_yaml_scalar(m_item.group(1)))
                    continue
            # Otherwise the pending list is done — flush before parsing
            # the next key.
            _flush_pending()
            # Are we still inside the wiki: block?
            if wiki_indent is not None and indent <= wiki_indent and line.strip():
                # Dedent past wiki: → leaving the block.
                in_wiki = False
                continue
            m_kv = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
            if not m_kv:
                continue
            key = m_kv.group(1)
            rest = m_kv.group(2).strip()
            m_list = _INLINE_LIST_RX.match(rest)
            if m_list:
                out[key] = _parse_inline_list(m_list.group(1))
            elif rest == "":
                # Block list opener — start collecting `- item` lines at a
                # deeper indent.
                pending_list_key = key
                pending_list_indent = indent + 1
                pending_list = []
            else:
                out[key] = _strip_yaml_scalar(rest)

    _flush_pending()
    return out


def load_wiki_config() -> tuple[tuple[str, ...], tuple[Path, ...]]:
    """Read .orchestrator/config.yml's wiki.code_prefixes + wiki.spec_paths.

    Returns (code_prefixes, spec_paths). Either may be empty; missing
    config file or absent keys both yield empty tuples.
    """
    cfg = ORCH / "config.yml"
    if not cfg.exists():
        return (), ()
    try:
        text = cfg.read_text(encoding="utf-8")
    except OSError:
        return (), ()
    parsed = _read_wiki_block(text)
    raw_prefixes = parsed.get("code_prefixes") or []
    raw_paths = parsed.get("spec_paths") or []
    if isinstance(raw_prefixes, str):
        raw_prefixes = [raw_prefixes]
    if isinstance(raw_paths, str):
        raw_paths = [raw_paths]
    prefixes = tuple(p for p in raw_prefixes if isinstance(p, str) and p)
    paths = tuple(ORCH / p for p in raw_paths if isinstance(p, str) and p)
    return prefixes, paths


# ---------- slugify (mkdocs/python-markdown TOC default) ----------

def slugify(text: str) -> str:
    s = text.strip().lower()
    s = re.sub(r"[^\w\- ]+", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s


# ---------- code-map construction ----------

def parse_decisions(path: Path) -> dict[str, tuple[str, str, str]]:
    """Parse DECISIONS.md.

    Catches two heading shapes:
      ### CODE — Title          (primary)
      - **`CODE`** — Title       (open-governance bullet shape)
      - **`CODE`**: Title
      - `CODE` — Title
    Bullets resolve to the same #section-CODE-title anchor (mkdocs assigns
    no anchor to bullets, so the link will fall through to a #unknown
    anchor — but we still emit the link with title because hovering a
    bullet-defined code is the higher-value affordance anyway).
    """
    out: dict[str, tuple[str, str, str]] = {}
    if not path.exists():
        return out
    target = "decisions.md"
    head_rx = re.compile(r"^###\s+([A-Z][A-Z0-9_-]+)\s*[—-]\s*(.+?)\s*$")
    bullet_rx_a = re.compile(
        r"^\s*-\s+\*\*`([A-Z][A-Z0-9_-]+)`\*\*\s*[—:-]\s*(.+?)\s*$"
    )
    bullet_rx_b = re.compile(
        r"^\s*-\s+`([A-Z][A-Z0-9_-]+)`\s*[—:-]\s*(.+?)\s*$"
    )
    for raw in path.read_text(encoding="utf-8").splitlines():
        # Strip backticks and stray markdown from extracted titles later.
        for rx in (head_rx, bullet_rx_a, bullet_rx_b):
            m = rx.match(raw)
            if not m:
                continue
            code, title = m.group(1), m.group(2).strip()
            # Truncate title at 120 chars for hover sanity.
            if len(title) > 120:
                title = title[:117].rstrip() + "…"
            slug = slugify(f"{code} - {title}")
            # Heading shape wins over bullet shape; first heading match
            # writes; later bullet-only definitions fill missing entries.
            if code in out and rx is not head_rx:
                continue
            out[code] = (title, target, slug)
            break
    return out


def parse_spec_table_codes(path: Path,
                           prefix: str) -> dict[str, tuple[str, str, str]]:
    """| CODE | Title | … rows."""
    out: dict[str, tuple[str, str, str]] = {}
    if not path.exists():
        return out
    try:
        rel = path.relative_to(ORCH).as_posix()
    except ValueError:
        # spec_paths entries should be .orchestrator-relative; if a
        # caller passed an absolute path outside ORCH, fall back to the
        # basename so the link target is still meaningful.
        rel = path.name
    target = rel  # wiki stub at the same relative path
    rx = re.compile(rf"^\|\s*({prefix}-\d+)\s*\|\s*([^|]+?)\s*\|")
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = rx.match(raw)
        if not m:
            continue
        code, title = m.group(1), m.group(2).rstrip(".").strip()
        if len(title) > 120:
            title = title[:117].rstrip() + "…"
        out[code] = (title, target, code.lower())
    return out


def build_code_map() -> dict[str, tuple[str, str, str]]:
    code_map: dict[str, tuple[str, str, str]] = {}
    code_map.update(parse_decisions(DECISIONS))
    for prefix in CODE_PREFIXES:
        for spec_path in SPEC_PATHS:
            code_map.update(parse_spec_table_codes(spec_path, prefix))
    return code_map


# ---------- heading-anchor index (per source file) ----------

HEADING_RX = re.compile(r"^(#+)\s+(.+?)\s*$")
# Capture leading section number from a heading: "2.1", "v3 §2.1.1", "8.2".
HEADING_NUM_RX = re.compile(
    r"^(?:v\d+\s+)?§?(\d+(?:\.\d+)*)\b"
)


def build_heading_index(text: str) -> tuple[set[str], dict[str, str]]:
    """Return (slug-set, number→slug map) for a markdown text body."""
    slugs: set[str] = set()
    num_to_slug: dict[str, str] = {}
    for raw in text.splitlines():
        m = HEADING_RX.match(raw)
        if not m:
            continue
        title = m.group(2).strip()
        slug = slugify(title)
        if not slug:
            continue
        slugs.add(slug)
        nm = HEADING_NUM_RX.match(title)
        if nm:
            num_to_slug.setdefault(nm.group(1), slug)
    return slugs, num_to_slug


# ---------- segment splitter (skip frontmatter + fenced code) ----------

def split_safe_segments(text: str) -> list[tuple[str, bool]]:
    segments: list[tuple[str, bool]] = []
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            segments.append((text[: end + 5], True))
            text = text[end + 5:]
        else:
            segments.append((text, True))
            return segments
    fence_rx = re.compile(r"(^|\n)(```|~~~)[^\n]*\n.*?\n\2", re.DOTALL)
    pos = 0
    while True:
        m = fence_rx.search(text, pos)
        if not m:
            segments.append((text[pos:], False))
            break
        if m.start() > pos:
            segments.append((text[pos:m.start()], False))
        segments.append((text[m.start():m.end()], True))
        pos = m.end()
    return segments


# ---------- decoration patterns ----------

PATH_RX_INNER = r"(?:\.orchestrator|knowledge)/[A-Za-z0-9_./-]+\.md"
PATH_PATTERN = re.compile(
    rf"(?<![A-Za-z0-9_/])(?:`({PATH_RX_INNER})`|({PATH_RX_INNER}))(?![A-Za-z0-9_])"
)

CODE_RX_INNER = r"[A-Z][A-Z0-9]*(?:-[A-Za-z0-9]+)+"
CODE_PATTERN = re.compile(
    rf"(?<![A-Za-z0-9_])(?:`({CODE_RX_INNER})`|({CODE_RX_INNER}))(?![A-Za-z0-9_/])"
)

# Bare milestone token: M### or M[A-Za-z0-9-]+ shape that resembles a
# milestone-id. We restrict to forms that begin with M-uppercase or
# M-digit and contain at least one hyphen-or-3-digit-suffix (so we don't
# decorate the bare letter "M").
MILESTONE_RX = re.compile(
    r"(?<![A-Za-z0-9_])(?:`(M(?:\d{3}|-[A-Za-z][A-Za-z0-9-]*|\d[A-Za-z]-(?:min|polish)))`"
    r"|(M(?:\d{3}|-[A-Za-z][A-Za-z0-9-]*|\d[A-Za-z]-(?:min|polish))))"
    r"(?![A-Za-z0-9_/-])"
)

# §-reference token: §N.N.N… — must be near a recently-seen path.
SECTION_RX = re.compile(r"§(\d+(?:\.\d+)*)")


def relpath_to_wiki(target_in_docs: str, page_wiki_dir: Path,
                    anchor: str = "") -> str:
    parts = page_wiki_dir.relative_to(WIKI_DOCS).parts
    rel = Path(*[".."] * len(parts)) / target_in_docs
    rel_str = rel.as_posix()
    return f"{rel_str}#{anchor}" if anchor else rel_str


_WIKI_DOCS_CI: dict[str, str] | None = None


def _wiki_docs_ci_map() -> dict[str, str]:
    """Lowercase-rel-path → actual-rel-path map of all wiki/docs/*.md.

    The wiki stub generator special-cases top-level uppercase
    .orchestrator/UPPERCASE.md to wiki/docs/lowercase.md (DECISIONS.md
    → decisions.md, KNOWLEDGE.md → knowledge.md, …). On case-insensitive
    filesystems (default macOS APFS) `(WIKI_DOCS / "DECISIONS.md").exists()`
    returns True even though mkdocs renders strictly case-sensitive
    paths. This map gives a case-insensitive fallback so we resolve to
    the actual stub name and emit a link mkdocs --strict accepts.
    """
    global _WIKI_DOCS_CI
    if _WIKI_DOCS_CI is not None:
        return _WIKI_DOCS_CI
    out: dict[str, str] = {}
    for p in WIKI_DOCS.rglob("*.md"):
        rel = p.relative_to(WIKI_DOCS).as_posix()
        out[rel.lower()] = rel
    _WIKI_DOCS_CI = out
    return out


def resolve_wiki_relative(rel: str) -> str | None:
    """Resolve a candidate wiki-relative path to the actual stub path
    (or None if no stub exists)."""
    actual = _wiki_docs_ci_map().get(rel.lower())
    return actual


# ---------- per-segment decoration ----------

def decorate_segment(text: str, code_map, page_wiki_dir: Path,
                     heading_index_cache: dict[str, tuple[set[str], dict[str, str]]],
                     milestone_dirs: set[str],
                     seen_milestones: set[str],
                     src_dir: Path | None = None) -> str:
    """Decorate a non-protected text segment.

    Existing markdown links/images don't get re-decorated, but their
    targets DO get rewritten when they point at a relative .md path
    that resolves into .orchestrator/ (the wiki has a stub at the
    parallel wiki/docs/ path; the link would 404 otherwise because
    rewrite-relative-urls is false on our stubs).
    """
    link_rx = re.compile(r"(!?\[[^\]]*\])\(([^)]*)\)")
    out_parts: list[str] = []
    pos = 0
    for m in link_rx.finditer(text):
        if m.start() > pos:
            out_parts.append(_decorate_plain(
                text[pos:m.start()], code_map, page_wiki_dir,
                heading_index_cache, milestone_dirs, seen_milestones,
            ))
        label = m.group(1)
        target = m.group(2)
        rewritten_target = _maybe_rewrite_existing_link_target(
            target, src_dir, page_wiki_dir,
        )
        out_parts.append(f"{label}({rewritten_target})")
        pos = m.end()
    if pos < len(text):
        out_parts.append(_decorate_plain(
            text[pos:], code_map, page_wiki_dir,
            heading_index_cache, milestone_dirs, seen_milestones,
        ))
    return "".join(out_parts)


def _maybe_rewrite_existing_link_target(target: str, src_dir: Path | None,
                                        page_wiki_dir: Path) -> str:
    """Rewrite a relative .md link target so it resolves to a wiki stub.

    Pre-existing source markdown looks like `[X](../DECISIONS.md)` or
    `[Y](../milestones/<name>/<NAME>-CONTEXT.md)`. When the source
    sits at .orchestrator/<rel>, those relative paths resolve into
    other .orchestrator/ files. Each such file has a wiki stub at
    wiki/docs/<rel>. Compute the wiki-relative path from page_wiki_dir
    so the rendered link points at the right stub.

    Targets that don't resolve into .orchestrator/ are left alone
    (external URLs, anchors-only, .text.md sibling refs, etc.).
    """
    if src_dir is None:
        return target
    if not target or target.startswith(("#", "http://", "https://", "mailto:", "data:")):
        return target
    # Split off any anchor fragment.
    anchor = ""
    if "#" in target:
        target_path, anchor = target.split("#", 1)
        anchor = "#" + anchor
    else:
        target_path = target
    if not target_path.endswith(".md"):
        return target
    # Resolve against source dir.
    try:
        resolved = (src_dir / target_path).resolve()
    except (OSError, RuntimeError):
        return target
    try:
        orch_rel = resolved.relative_to(ORCH).as_posix()
    except ValueError:
        return target
    actual = resolve_wiki_relative(orch_rel)
    if actual is None:
        return target
    try:
        rel = (Path(*[".."] * len(page_wiki_dir.relative_to(WIKI_DOCS).parts))
               / actual)
    except ValueError:
        return target
    return rel.as_posix() + anchor


def _heading_index_for(rel: str,
                       cache: dict[str, tuple[set[str], dict[str, str]]]
                       ) -> tuple[set[str], dict[str, str]]:
    if rel in cache:
        return cache[rel]
    src = ORCH / rel
    if not src.exists():
        idx: tuple[set[str], dict[str, str]] = (set(), {})
    else:
        idx = build_heading_index(src.read_text(encoding="utf-8"))
    cache[rel] = idx
    return idx


def anchor_exists_in_target(target_in_docs: str, anchor: str,
                            heading_cache) -> bool:
    """Verify an anchor exists in the target wiki page's source.

    target_in_docs is wiki-relative (e.g. 'decisions.md',
    'spec/<plan>.md'). The underlying source is .orchestrator/<same-
    relative-path> for stubbed pages. Returns True if the anchor is in
    the heading-set; False if not (and we should drop the fragment to
    keep mkdocs --strict happy).
    """
    if not anchor:
        return True
    if target_in_docs == "decisions.md":
        orch_rel = "DECISIONS.md"
    else:
        orch_rel = target_in_docs
    slugs, _ = _heading_index_for(orch_rel, heading_cache)
    return anchor in slugs


def _decorate_plain(text: str, code_map, page_wiki_dir: Path,
                    heading_cache, milestone_dirs, seen_milestones) -> str:
    # Pass 1: paths. Track each path's offset so §-references nearby can
    # resolve their target file.
    path_hits: list[tuple[int, int, str]] = []  # (start_in_output, end, .orchestrator-rel)

    def path_repl(m: re.Match) -> str:
        in_backticks = m.group(1) is not None
        path_str = m.group(1) if in_backticks else m.group(2)
        if path_str.startswith(".orchestrator/"):
            wiki_relative = path_str[len(".orchestrator/"):]
        elif path_str.startswith("knowledge/"):
            wiki_relative = path_str
        else:
            return m.group(0)
        # Case-insensitive resolution: the stub generator lowercases
        # top-level UPPERCASE.md filenames (DECISIONS.md → decisions.md).
        actual = resolve_wiki_relative(wiki_relative)
        if actual is None:
            return m.group(0)
        try:
            rel = (Path(*[".."] * len(page_wiki_dir.relative_to(WIKI_DOCS).parts))
                   / actual)
        except ValueError:
            return m.group(0)
        rel_str = rel.as_posix()
        if in_backticks:
            return f'[`{path_str}`]({rel_str})'
        return f'[{path_str}]({rel_str})'

    text = PATH_PATTERN.sub(path_repl, text)

    # Re-scan output for path-link offsets (now they're markdown links).
    # Track only orchestrator-shape link targets so §-resolution finds them.
    path_link_rx = re.compile(
        r"\[`?([^\]`]+\.md)`?\]\(([^)]+\.md)\)"
    )
    for m in path_link_rx.finditer(text):
        # Identify the original .orchestrator-relative path from the link
        # text. The decorator wrote the original path string as link text.
        link_text = m.group(1)
        if link_text.startswith(".orchestrator/"):
            orch_rel = link_text[len(".orchestrator/"):]
            path_hits.append((m.start(), m.end(), orch_rel))
        elif link_text.startswith("knowledge/"):
            path_hits.append((m.start(), m.end(), link_text))

    # Pass 2: §-references near a path-link (within ~80 chars).
    if path_hits:
        def section_repl(m: re.Match) -> str:
            num = m.group(1)
            pos_match = m.start()
            # Find nearest preceding path-hit ending within 200 chars,
            # with the §-token within 80 chars of it (distance from path
            # end to §-token start). Heuristic balance: a same-paragraph
            # tolerance.
            best: tuple[int, str] | None = None
            for ps, pe, rel in path_hits:
                if pe > pos_match:
                    continue
                dist = pos_match - pe
                if dist > 80:
                    continue
                if best is None or dist < best[0]:
                    best = (dist, rel)
            if best is None:
                return m.group(0)
            rel = best[1]
            # Resolve heading-anchor for this number.
            if rel.startswith(".orchestrator/"):
                rel_path = rel[len(".orchestrator/"):]
            else:
                rel_path = rel
            # heading_cache key uses the .orchestrator-relative path.
            slugs, num_to_slug = _heading_index_for(rel_path, heading_cache)
            anchor = num_to_slug.get(num)
            if not anchor:
                return m.group(0)
            try:
                rel_link = (Path(*[".."] * len(page_wiki_dir.relative_to(WIKI_DOCS).parts))
                            / rel_path)
            except ValueError:
                return m.group(0)
            url = f"{rel_link.as_posix()}#{anchor}"
            return f"[§{num}]({url})"

        text = SECTION_RX.sub(section_repl, text)

    # Pass 3: codes.
    def code_repl(m: re.Match) -> str:
        in_backticks = m.group(1) is not None
        code = m.group(1) if in_backticks else m.group(2)
        if code not in code_map:
            return m.group(0)
        title, target, anchor = code_map[code]
        # Verify the anchor exists in the target. Spec-table-row codes
        # point at table rows that have no auto-generated anchor; without
        # verification, mkdocs --strict warns "doc does not contain
        # anchor" 60+ times. When the anchor is missing, drop the
        # fragment but keep the page-level link + tooltip — clicking
        # lands on the page; the user finds the row.
        if not anchor_exists_in_target(target, anchor, heading_cache):
            anchor = ""
        url = relpath_to_wiki(target, page_wiki_dir, anchor)
        safe_title = title.replace('"', "&quot;")
        if in_backticks:
            return f'[`{code}`]({url} "{safe_title}")'
        return f'[{code}]({url} "{safe_title}")'

    text = CODE_PATTERN.sub(code_repl, text)

    # Pass 4: bare milestone names (first occurrence per page).
    def milestone_repl(m: re.Match) -> str:
        in_backticks = m.group(1) is not None
        name = m.group(1) if in_backticks else m.group(2)
        if name not in milestone_dirs:
            return m.group(0)
        if name in seen_milestones:
            return m.group(0)
        seen_milestones.add(name)
        target = f"milestones/{name}/index.md"
        try:
            rel = (Path(*[".."] * len(page_wiki_dir.relative_to(WIKI_DOCS).parts))
                   / target)
        except ValueError:
            return m.group(0)
        if in_backticks:
            return f'[`{name}`]({rel.as_posix()})'
        return f'[{name}]({rel.as_posix()})'

    text = MILESTONE_RX.sub(milestone_repl, text)

    return text


def decorate(text: str, code_map, page_wiki_dir: Path,
             heading_cache, milestone_dirs,
             src_dir: Path | None = None) -> str:
    # Suppress self-referential milestone links: when the page lives at
    # wiki/docs/milestones/<NAME>/..., skip decorations of <NAME> on this
    # page (otherwise the H1 / index back-references self-link to nowhere
    # useful).
    seen_milestones: set[str] = set()
    parts = page_wiki_dir.relative_to(WIKI_DOCS).parts
    if len(parts) >= 2 and parts[0] == "milestones":
        seen_milestones.add(parts[1])
    pieces: list[str] = []
    for seg, protected in split_safe_segments(text):
        if protected:
            pieces.append(seg)
        else:
            pieces.append(decorate_segment(
                seg, code_map, page_wiki_dir, heading_cache,
                milestone_dirs, seen_milestones, src_dir,
            ))
    return "".join(pieces)


# ---------- stub parsing + rewriting ----------

INCLUDE_DIRECTIVE_RX = re.compile(
    r"\{%\s*\n?\s*include-markdown\s+\"([^\"]+)\"\s*\n"
    r"((?:\s+[a-z-]+=[^\n]+\n)*)"
    r"\s*%\}",
    re.MULTILINE,
)

ADMONITION_MARKER = "<!-- decorate-build: plain-English admonition (auto) -->"


def parse_stub_include(stub_path: Path) -> tuple[re.Match, str, str] | None:
    """Return (match, source_path_in_directive, options_block) or None.

    source_path_in_directive is exactly as it appears (relative path with
    `..` traversal, e.g. `../../../../.orchestrator/milestones/X/Y.md`).
    """
    text = stub_path.read_text(encoding="utf-8")
    m = INCLUDE_DIRECTIVE_RX.search(text)
    if not m:
        return None
    return (m, m.group(1), m.group(2))


def resolve_orch_relative(stub_path: Path, include_target: str) -> str | None:
    """Resolve the include directive's path to a path relative to ORCH.

    Returns e.g. 'milestones/<name>/<NAME>-CONTEXT.md' for an include of
    '.../.orchestrator/milestones/<name>/<NAME>-CONTEXT.md', or None if
    it doesn't reference .orchestrator/.
    """
    abs_target = (stub_path.parent / include_target).resolve()
    try:
        return abs_target.relative_to(ORCH).as_posix()
    except ValueError:
        return None


def is_already_staged(include_target: str) -> bool:
    return "/.staged/" in include_target or include_target.startswith(".staged/")


def resolve_staged_relative(stub_path: Path, include_target: str) -> str | None:
    """If the stub already includes from .staged/, resolve the relative
    path to one rooted at WIKI_STAGED."""
    abs_target = (stub_path.parent / include_target).resolve()
    try:
        return abs_target.relative_to(WIKI_STAGED).as_posix()
    except ValueError:
        return None


def compute_staged_include_path(stub_path: Path, orch_rel: str) -> str:
    """Build the relative include path from stub_path to
    WIKI_STAGED / orch_rel."""
    target = WIKI_STAGED / orch_rel
    return os.path.relpath(target, start=stub_path.parent)


def rewrite_stub_include(stub_path: Path, orch_rel: str,
                         summary_body: str | None) -> bool:
    """Rewrite stub to include from .staged/ + prepend summary admonition.

    Returns True if the stub file content changed.
    """
    text = stub_path.read_text(encoding="utf-8")
    parsed = parse_stub_include(stub_path)
    if parsed is None:
        return False
    m, _src, options = parsed

    new_include_path = compute_staged_include_path(stub_path, orch_rel)
    # Force rewrite-relative-urls=false, preserve other options as-is.
    new_options_lines: list[str] = []
    saw_rrurl = False
    for line in options.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("rewrite-relative-urls"):
            saw_rrurl = True
            new_options_lines.append("  rewrite-relative-urls=false")
        else:
            new_options_lines.append("  " + s)
    if not saw_rrurl:
        new_options_lines.append("  rewrite-relative-urls=false")
    new_directive = (
        "{%\n"
        f'  include-markdown "{new_include_path}"\n'
        + "\n".join(new_options_lines) + "\n"
        "%}"
    )
    new_text = text[:m.start()] + new_directive + text[m.end():]

    # Manage admonition: detect and replace existing block, or prepend.
    if summary_body is not None:
        admonition = build_admonition(summary_body)
        new_text = inject_admonition(new_text, admonition)
    else:
        # Strip a stale admonition if present.
        new_text = strip_admonition(new_text)

    if new_text == text:
        return False
    stub_path.write_text(new_text, encoding="utf-8")
    return True


def build_admonition(body: str) -> str:
    body = body.strip("\n")
    indented = "\n".join(
        ("    " + line) if line.strip() else "" for line in body.splitlines()
    )
    return (
        f"{ADMONITION_MARKER}\n"
        '!!! info "In plain English"\n'
        f"{indented}\n"
    )


ADMONITION_BLOCK_RX = re.compile(
    re.escape(ADMONITION_MARKER) + r"\n!!! info \"In plain English\"\n"
    r"(?:    .*\n|\n)*",
    re.MULTILINE,
)


def strip_admonition(text: str) -> str:
    return ADMONITION_BLOCK_RX.sub("", text)


def inject_admonition(text: str, admonition: str) -> str:
    """Insert admonition before the first include-markdown block.

    If an existing admonition block (marker-tagged) exists, replace it.
    Otherwise insert immediately before the include directive.
    """
    if ADMONITION_MARKER in text:
        text = ADMONITION_BLOCK_RX.sub(admonition, text, count=1)
        return text
    m = INCLUDE_DIRECTIVE_RX.search(text)
    if not m:
        return text
    return text[:m.start()] + admonition + "\n" + text[m.start():]


# ---------- summary-sibling lookup ----------

def find_summary_sibling(stub_path: Path) -> Path | None:
    sib = stub_path.with_suffix("").with_name(stub_path.stem + ".summary.md")
    if sib.exists():
        return sib
    return None


# ---------- milestone-dirs cache ----------

def list_milestone_dirs() -> set[str]:
    base = WIKI_DOCS / "milestones"
    if not base.exists():
        return set()
    return {p.name for p in base.iterdir() if p.is_dir()}


# ---------- driver ----------

def find_stubs() -> list[Path]:
    """All wiki/docs/**/*.md files that contain an include-markdown
    directive whose target is `.orchestrator/...md` or `.staged/...md`."""
    out: list[Path] = []
    for path in WIKI_DOCS.rglob("*.md"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "include-markdown" not in text:
            continue
        m = INCLUDE_DIRECTIVE_RX.search(text)
        if not m:
            continue
        target = m.group(1)
        if "/.orchestrator/" in target or ".orchestrator/" in target.split("/")[-2:]:
            out.append(path)
        elif "/.staged/" in target or target.startswith(".staged/"):
            out.append(path)
    return out


def needs_regeneration(src: Path, dst: Path, force: bool) -> bool:
    if force:
        return True
    if not dst.exists():
        return True
    return src.stat().st_mtime > dst.stat().st_mtime


def process_stub(stub: Path, code_map, heading_cache, milestone_dirs,
                 force: bool, missing_summaries: list[Path]) -> bool:
    """Process one stub: decorate the included source into .staged/,
    rewrite the stub include + admonition, touch stub mtime.

    Returns True if anything changed.
    """
    parsed = parse_stub_include(stub)
    if parsed is None:
        return False
    _m, include_target, _options = parsed

    # Resolve the .orchestrator-relative path.
    orch_rel: str | None = None
    if "/.orchestrator/" in include_target or include_target.startswith(".orchestrator/") or "../" in include_target:
        orch_rel = resolve_orch_relative(stub, include_target)
    if orch_rel is None and is_already_staged(include_target):
        # Already pointing at .staged — recover orch path from staged.
        staged_rel = resolve_staged_relative(stub, include_target)
        if staged_rel is not None:
            orch_rel = staged_rel
    if orch_rel is None:
        return False

    src = ORCH / orch_rel
    if not src.exists():
        return False

    staged_dst = WIKI_STAGED / orch_rel

    # Summary sibling.
    sib = find_summary_sibling(stub)
    summary_body: str | None = None
    if sib is not None:
        summary_body = sib.read_text(encoding="utf-8")
    else:
        missing_summaries.append(stub)

    changed = False

    # Decoration: only re-emit when source changed (mtime) or stub needs it.
    if needs_regeneration(src, staged_dst, force):
        page_wiki_dir = stub.parent
        text = src.read_text(encoding="utf-8")
        out = decorate(text, code_map, page_wiki_dir,
                       heading_cache, list_milestone_dirs(),
                       src_dir=src.parent)
        staged_dst.parent.mkdir(parents=True, exist_ok=True)
        # Write only if content differs.
        existing = staged_dst.read_text(encoding="utf-8") if staged_dst.exists() else None
        if existing != out:
            staged_dst.write_text(out, encoding="utf-8")
            changed = True
        else:
            # Bump mtime so next mtime-skip considers it fresh.
            os.utime(staged_dst, None)

    # Stub include rewrite + admonition prepend.
    stub_changed = rewrite_stub_include(stub, orch_rel, summary_body)
    if stub_changed:
        changed = True

    # Touch the stub so mkdocs serve picks up staged changes.
    if changed:
        os.utime(stub, None)

    return changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="Regenerate every staged file regardless of mtime.")
    ap.add_argument("--print-map", action="store_true",
                    help="Dump the code map to stderr and exit.")
    ap.add_argument("--only", action="append", default=[],
                    help="Limit processing to one or more stub paths "
                         "(relative to wiki/docs/).")
    ap.add_argument("--root", type=Path,
                    help="Override the project root (used by "
                         "wiki-stubs-fresh.sh against a staged tmp tree).")
    args = ap.parse_args()

    if args.root is not None:
        _rebind_paths(args.root.resolve())

    # Re-load wiki config after path rebinding so --root sees the
    # project-local config (not the upstream framework's).
    global CODE_PREFIXES, SPEC_PATHS
    CODE_PREFIXES, SPEC_PATHS = load_wiki_config()

    code_map = build_code_map()
    if args.print_map:
        for code in sorted(code_map):
            title, target, anchor = code_map[code]
            print(f"{code}\t{title}\t{target}#{anchor}", file=sys.stderr)
        return 0

    heading_cache: dict[str, tuple[set[str], dict[str, str]]] = {}
    milestone_dirs = list_milestone_dirs()

    if args.only:
        stubs = [WIKI_DOCS / p for p in args.only]
    else:
        stubs = find_stubs()

    missing_summaries: list[Path] = []
    changed_count = 0
    skipped_count = 0
    error_count = 0
    for stub in stubs:
        try:
            if process_stub(stub, code_map, heading_cache, milestone_dirs,
                            args.force, missing_summaries):
                changed_count += 1
            else:
                skipped_count += 1
        except Exception as e:  # pragma: no cover
            print(f"ERR: {stub}: {e}", file=sys.stderr)
            error_count += 1

    # Emit summary-todo manifest.
    if missing_summaries:
        lines = [
            "# Wiki plain-English summary TODO",
            "",
            f"Generated by scripts/wiki/wiki-decorate-build.py — {len(missing_summaries)} stub(s) missing a `<page>.summary.md` sibling.",
            "",
            "Authoring: 3–5 short paragraphs in plain prose, no DR/AN/BG codes.",
            "Convention: a sibling file `<page>.summary.md` at the same directory as the stub. The decorator wraps it in `!!! info \"In plain English\"`.",
            "",
        ]
        for s in sorted(missing_summaries):
            rel = s.relative_to(REPO_ROOT)
            sib = s.with_suffix("").with_name(s.stem + ".summary.md").relative_to(REPO_ROOT)
            lines.append(f"- [ ] `{rel}` → author `{sib}`")
        SUMMARY_TODO.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(
        f"OK: {len(stubs)} stub(s); {changed_count} changed, "
        f"{skipped_count} unchanged, {error_count} errors. "
        f"{len(missing_summaries)} missing summary. "
        f"Code map: {len(code_map)} entries.",
        file=sys.stderr,
    )
    return 0 if error_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

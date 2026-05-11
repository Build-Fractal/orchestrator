#!/usr/bin/env python3
"""Synthesize a conversus.yml from an orchestrator preset + artifact.

Invoked by scripts/dispatch/adapters/tool/conversus.sh via the conversus
pipx venv's Python (so PyYAML is guaranteed). The orchestrator's presets
(templates/conversus-presets/*.yml) declare agents + arbiter in a shape
that almost-but-not-quite matches conversus's native config schema; this
helper bridges the last mile:

  preset.system_prompt        -> agent.prompt
  preset.arbiter.grounding_file  -> arbiter.grounding + arbiter.docs
  preset.arbiter.grounding_files -> arbiter.grounding (first) + arbiter.docs
                                    (all). List form; either key works.
  preset.arbiter.description  -> arbiter.prompt (the role charter for the
                                 arbiter, which conversus treats as a
                                 real agent with its own system prompt)

Red-blue mode gets role hints (blue-advocate -> role: blue, red-advocate
-> role: red) so conversus's red-blue pipeline can categorize them.

Args:
  --preset <path>      orchestrator preset YAML (two-frontmatter format)
  --artifact <path>    file being deliberated over
  --output-dir <path>  where conversus should write its output tree
  --out <path>         where to write the synthesized conversus.yml
  --source <path>      (optional, repeatable) grounding source document;
                       each --source is appended to every agent's `docs:`
                       list so advocates can compare the artifact against
                       its source(s). Tier 2 fidelity passes one source;
                       constitution-ratify presets pass two
                       (constitution.md + CONFORMANCE.md).

Exit codes: 0 on success, 1 on parse/write error.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: PyYAML not available in this interpreter", file=sys.stderr)
    sys.exit(1)


def _strip_orchestrator_frontmatter(raw: str) -> str:
    """Drop the orchestrator's two-frontmatter header if present.

    Orchestrator presets carry a schema_version/type block fenced by `---`
    lines before the conversus-shaped body. We strip it before handing
    the body to yaml.safe_load.
    """
    lines = raw.splitlines()
    if lines and lines[0].strip() == "---":
        # Find the closing --- of the first frontmatter block
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                return "\n".join(lines[i + 1:])
    return raw


def _derive_role(agent_name: str, mode: str) -> str | None:
    """Return a red-blue role hint if the agent name telegraphs one."""
    if mode != "red-blue":
        return None
    n = agent_name.lower()
    if "blue" in n:
        return "blue"
    if "red" in n:
        return "red"
    return None


def synthesize(
    preset_path: Path,
    artifact: Path,
    output_dir: Path,
    sources: list[Path] | None = None,
) -> dict:
    raw = preset_path.read_text(encoding="utf-8")
    body = _strip_orchestrator_frontmatter(raw)
    preset = yaml.safe_load(body)
    if not isinstance(preset, dict):
        raise ValueError(f"preset body did not parse to a mapping: {preset_path}")

    mode = preset.get("mode")
    if not mode:
        raise ValueError(f"preset missing 'mode': {preset_path}")

    preset_agents = preset.get("agents") or []
    if not preset_agents:
        raise ValueError(f"preset has no agents: {preset_path}")

    source_abs_list = [str(s.resolve()) for s in (sources or [])]

    conv_agents = []
    for a in preset_agents:
        name = a.get("name")
        prompt = a.get("system_prompt") or a.get("prompt")
        if not name or not prompt:
            raise ValueError(f"agent missing name/system_prompt in {preset_path}")
        entry: dict = {"name": name, "prompt": prompt}
        role = _derive_role(name, mode)
        if role is not None:
            entry["role"] = role
        if source_abs_list:
            preset_docs = a.get("docs") or []
            entry["docs"] = list(preset_docs) + source_abs_list
        conv_agents.append(entry)

    config: dict = {
        "mode": mode,
        "target": str(artifact.resolve()),
        "output": str(output_dir.resolve()),
        "iterations": 1,
        "agents": conv_agents,
    }

    preset_arbiter = preset.get("arbiter")
    if preset_arbiter:
        # Accept either `grounding_file:` (single string, legacy) or
        # `grounding_files:` (list, multi-source). Both keys may appear;
        # entries are concatenated in declared order with the singular
        # field first to preserve back-compat for callers that read
        # `arbiter.grounding` as the canonical (first) doc.
        grounding_entries: list[str] = []
        single = preset_arbiter.get("grounding_file")
        if single:
            grounding_entries.append(single)
        multi = preset_arbiter.get("grounding_files") or []
        if not isinstance(multi, list):
            raise ValueError(
                f"preset arbiter grounding_files must be a list: {preset_path}"
            )
        grounding_entries.extend(multi)
        if not grounding_entries:
            raise ValueError(
                f"preset arbiter missing grounding_file/grounding_files: {preset_path}"
            )

        grounding_abs_list: list[str] = []
        for g in grounding_entries:
            g_abs = (preset_path.parent / g).resolve()
            if not g_abs.exists():
                # Try resolving from repo root (preset path is typically
                # templates/conversus-presets/*.yml; go up two levels)
                repo_root = preset_path.parent.parent.parent
                g_abs = (repo_root / g).resolve()
            grounding_abs_list.append(str(g_abs))

        arbiter_prompt = preset_arbiter.get("description") or (
            "You arbitrate disputes between the advocates. "
            "Weigh each dispute against the grounding document and "
            "emit a structured verdict."
        )
        config["arbiter"] = {
            "name": preset_arbiter.get("name") or "arbiter",
            "prompt": arbiter_prompt,
            "docs": list(grounding_abs_list),
            "grounding": grounding_abs_list[0],
            "trigger": preset_arbiter.get("trigger") or "disputes_remain",
        }

    return config


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", required=True, type=Path)
    ap.add_argument("--artifact", required=True, type=Path)
    ap.add_argument("--output-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument(
        "--source",
        required=False,
        type=Path,
        action="append",
        default=None,
        help="grounding source document; repeat to pass multiple",
    )
    args = ap.parse_args()

    for label, path in (("preset", args.preset), ("artifact", args.artifact)):
        if not path.exists():
            print(f"error: {label} not found: {path}", file=sys.stderr)
            return 1
    sources: list[Path] = list(args.source or [])
    for s in sources:
        if not s.exists():
            print(f"error: source not found: {s}", file=sys.stderr)
            return 1

    try:
        config = synthesize(args.preset, args.artifact, args.output_dir, sources)
    except (ValueError, yaml.YAMLError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        yaml.safe_dump(config, f, sort_keys=False, default_flow_style=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Synthesize a conversus.yml from an orchestrator preset + artifact.

Invoked by scripts/dispatch/adapters/tool/conversus.sh via the conversus
pipx venv's Python (so PyYAML is guaranteed). The orchestrator's presets
(templates/conversus-presets/*.yml) declare agents + arbiter in a shape
that almost-but-not-quite matches conversus's native config schema; this
helper bridges the last mile:

  preset.system_prompt        -> agent.prompt
  preset.arbiter.grounding_file -> arbiter.grounding + arbiter.docs
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
  --source <path>      (optional) grounding source document; when set, the
                       path is appended to each agent's `docs:` list so
                       the fidelity-advocate can compare the artifact
                       against its source. Used by tier-2-fidelity.

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
    source: Path | None = None,
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

    source_abs = str(source.resolve()) if source is not None else None

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
        if source_abs is not None:
            preset_docs = a.get("docs") or []
            entry["docs"] = list(preset_docs) + [source_abs]
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
        grounding = preset_arbiter.get("grounding_file")
        if not grounding:
            raise ValueError(f"preset arbiter missing grounding_file: {preset_path}")
        grounding_abs = (preset_path.parent / grounding).resolve()
        if not grounding_abs.exists():
            # Try resolving from repo root (preset path is typically
            # templates/conversus-presets/*.yml; go up two levels)
            repo_root = preset_path.parent.parent.parent
            grounding_abs = (repo_root / grounding).resolve()
        arbiter_prompt = preset_arbiter.get("description") or (
            "You arbitrate disputes between the advocates. "
            "Weigh each dispute against the grounding document and "
            "emit a structured verdict."
        )
        config["arbiter"] = {
            "name": preset_arbiter.get("name") or "arbiter",
            "prompt": arbiter_prompt,
            "docs": [str(grounding_abs)],
            "grounding": str(grounding_abs),
            "trigger": preset_arbiter.get("trigger") or "disputes_remain",
        }

    return config


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", required=True, type=Path)
    ap.add_argument("--artifact", required=True, type=Path)
    ap.add_argument("--output-dir", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--source", required=False, type=Path, default=None)
    args = ap.parse_args()

    for label, path in (("preset", args.preset), ("artifact", args.artifact)):
        if not path.exists():
            print(f"error: {label} not found: {path}", file=sys.stderr)
            return 1
    if args.source is not None and not args.source.exists():
        print(f"error: source not found: {args.source}", file=sys.stderr)
        return 1

    try:
        config = synthesize(args.preset, args.artifact, args.output_dir, args.source)
    except (ValueError, yaml.YAMLError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        yaml.safe_dump(config, f, sort_keys=False, default_flow_style=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())

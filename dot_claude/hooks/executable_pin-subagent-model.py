#!/usr/bin/env python3
"""PreToolUse hook that enforces subagent models from agent frontmatter.

Custom agents take their model only from the matching ``name:`` in agent-file
frontmatter.  Project definitions are searched nearest-first, then user
configuration; malformed matching definitions fail closed to Sonnet.  Built-in
agent types also use Sonnet, while forks inherit their parent's model.
"""
import json
import os
from pathlib import Path
import re
import sys
from typing import Any

DEFAULT_MODEL = "sonnet"
FRONTMATTER_MODEL_ALIASES = {
    "claude-sonnet-5": "sonnet",
    "claude-opus-5-5": "opus",
    "claude-haiku-4-5-20251001": "haiku",
    "sonnet": "sonnet",
    "opus": "opus",
    "haiku": "haiku",
    "fable": "fable",
}
BUILTIN_TYPES = {"Explore", "Plan", "general-purpose"}
UNPINNABLE_TYPES = {"fork"}
FIELD_RE = re.compile(r"^(name|model):[ \t]*(.*)$")


def task_label(value: object) -> str:
    if not isinstance(value, str):
        return "unnamed"
    label = re.sub(r"\s+", " ", value).replace("·", "-").strip()
    return label[:56] or "unnamed"


def scalar(value: str) -> str | None:
    """Accept only plain or simply quoted YAML-like scalar values."""
    value = value.strip()
    if not value:
        return None
    if value[0] in "\"'":
        quote = value[0]
        if len(value) < 2 or value[-1] != quote or quote in value[1:-1]:
            return None
        value = value[1:-1]
        return value or None
    if any(character in value for character in "[]{}&,*!|>@#\"") or value.startswith(("-", "?", ":")):
        return None
    return value


def frontmatter(path: Path) -> tuple[str | None, str | None, bool]:
    """Return name, model, and whether the narrow frontmatter is valid."""
    try:
        with path.open(encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return None, None, False
    if not lines or lines[0].strip() != "---":
        return None, None, False
    fields: dict[str, str | None] = {}
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        match = FIELD_RE.match(line)
        if match:
            key, raw = match.groups()
            if key in fields:
                return fields.get("name"), None, False
            fields[key] = scalar(raw)
    name = fields.get("name")
    model = fields.get("model")
    return name, model, closed and name is not None and model is not None


def matching_definition(directory: Path, name: str) -> tuple[bool, str | None]:
    """Return a sole valid matching model, failing closed on ambiguity or invalidity."""
    try:
        paths = sorted(directory.glob("*.md"))
    except OSError:
        return False, None
    matches: list[tuple[str | None, bool]] = []
    for path in paths:
        parsed_name, model, valid = frontmatter(path)
        # A malformed file cannot always supply a parsed name.  Its stem is
        # evidence of intent only in that invalid case; valid definitions are
        # identified exclusively by their frontmatter name.
        if parsed_name == name or (not valid and path.stem == name):
            matches.append((model, valid))
    if len(matches) != 1:
        return bool(matches), None
    model, valid = matches[0]
    return True, model if valid else None


def project_agent_directories(cwd: object) -> list[Path]:
    if not isinstance(cwd, str) or not cwd:
        return []
    try:
        current = Path(cwd).resolve(strict=True)
        home = Path.home().resolve(strict=True)
    except OSError:
        return []
    if not current.is_dir():
        return []
    directories: list[Path] = []
    while current != home:
        directories.append(current / ".claude" / "agents")
        if current.parent == current:
            break
        current = current.parent
    return directories


def config_directory() -> Path:
    return Path(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")).expanduser()


def custom_model(name: str, cwd: object) -> str | None:
    for directory in project_agent_directories(cwd):
        matched, model = matching_definition(directory, name)
        if matched:
            return model
    matched, model = matching_definition(config_directory() / "agents", name)
    return model if matched else None


def model_alias(declared_model: object) -> str:
    """Translate an allowed frontmatter model to an Agent API model alias."""
    if not isinstance(declared_model, str):
        return DEFAULT_MODEL
    return FRONTMATTER_MODEL_ALIASES.get(declared_model, DEFAULT_MODEL)


def main() -> None:
    try:
        payload: dict[str, Any] = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("{}")
        return
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        print("{}")
        return

    raw_type = tool_input.get("subagent_type")
    subagent_type = raw_type if isinstance(raw_type, str) and raw_type else "general-purpose"
    requested = tool_input.get("model")
    requested_label = requested if isinstance(requested, str) else "default"
    task = task_label(tool_input.get("description"))

    if subagent_type in UNPINNABLE_TYPES:
        print(json.dumps({"systemMessage": f"model policy · {subagent_type} · task={task} · requested={requested_label} · declared=fallback · enforced=inherit"}))
        return

    if subagent_type in BUILTIN_TYPES:
        declared_model: str | None = None
    else:
        declared_model = custom_model(subagent_type, payload.get("cwd"))
    declared_label = declared_model if declared_model is not None else "fallback"
    enforced_model = model_alias(declared_model)
    output = {
        "systemMessage": f"model policy · {subagent_type} · task={task} · requested={requested_label} · declared={declared_label} · enforced={enforced_model}",
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "updatedInput": {**tool_input, "model": enforced_model},
        },
    }
    print(json.dumps(output))


if __name__ == "__main__":
    main()

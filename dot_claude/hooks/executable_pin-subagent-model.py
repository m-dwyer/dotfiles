#!/usr/bin/env python3
"""PreToolUse hook on Agent: enforce the subagent model policy.

Claude Code 2.1.251 made the invocation-level `model` the highest-precedence
subagent model input. `updatedInput.model` therefore overrides both agent
frontmatter and a model the harness requested. The Agent tool accepts a family
alias here, while settings.json pins those aliases to exact model releases.

Unknown named agents degrade to Sonnet. Planner is the only Opus exception.
Forks cannot accept a model override and are reported but left inheriting the
parent model.
"""
import json
import re
import sys

# subagent_type -> invocation-level model alias.
MODEL_POLICY = {
    "scout": "sonnet",
    "coder": "sonnet",
    "reviewer": "sonnet",
    "planner": "opus",
    "Explore": "sonnet",
    "Plan": "sonnet",
    "general-purpose": "sonnet",
}
DEFAULT_MODEL = "sonnet"
UNPINNABLE_TYPES = {"fork"}


def task_label(value: object) -> str:
    if not isinstance(value, str):
        return "unnamed"
    label = re.sub(r"\s+", " ", value).replace("·", "-").strip()
    return label[:56] or "unnamed"


def main() -> None:
    try:
        payload = json.load(sys.stdin)
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
        print(
            json.dumps(
                {
                    "systemMessage": (
                        f"model policy · {subagent_type} · task={task} · "
                        f"requested={requested_label} · enforced=inherit"
                    )
                }
            )
        )
        return

    model = MODEL_POLICY.get(subagent_type, DEFAULT_MODEL)
    output = {
        "systemMessage": (
            f"model policy · {subagent_type} · task={task} · "
            f"requested={requested_label} · enforced={model}"
        )
    }

    if requested != model:
        output["hookSpecificOutput"] = {
            "hookEventName": "PreToolUse",
            "updatedInput": {**tool_input, "model": model},
        }

    print(json.dumps(output))


if __name__ == "__main__":
    main()

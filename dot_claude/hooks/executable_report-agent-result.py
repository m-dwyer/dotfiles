#!/usr/bin/env python3
"""Show the model that actually served a completed Agent invocation."""

import json
import re
import sys
from typing import Any


def safe_text(value: Any, default: str = "unknown") -> str:
    if not isinstance(value, str) or not value:
        return default
    return re.sub(r"[^A-Za-z0-9_.:+<>=/-]", "?", value)[:120]


def task_label(value: Any) -> str:
    if not isinstance(value, str):
        return "unnamed"
    label = re.sub(r"\s+", " ", value).replace("·", "-").strip()
    return label[:56] or "unnamed"


def response_text(response: dict[str, Any]) -> str:
    content = response.get("content")
    if not isinstance(content, list):
        return ""
    return "\n".join(
        block.get("text", "")
        for block in content
        if isinstance(block, dict) and isinstance(block.get("text"), str)
    )


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("{}")
        return

    tool_input = payload.get("tool_input")
    response = payload.get("tool_response")
    if not isinstance(tool_input, dict) or not isinstance(response, dict):
        print("{}")
        return

    agent_type = safe_text(
        response.get("agentType") or tool_input.get("subagent_type"),
        "subagent",
    )
    actual = safe_text(response.get("resolvedModel"))
    if actual == "unknown":
        print("{}")
        return
    task = task_label(tool_input.get("description"))
    if re.search(r"stopped at its \d+-turn limit before finishing", response_text(response)):
        outcome = "partial:turn-limit"
    else:
        outcome = "complete"

    print(
        json.dumps(
            {
                "systemMessage": (
                    f"model result · {agent_type} · task={task} · "
                    f"actual={actual} · outcome={outcome}"
                )
            }
        )
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Report requested, enforced, and actual subagent model usage.

Subagent transcripts repeat one assistant message for each content/tool block.
Usage is therefore deduplicated by message.id. A small state file records which
message IDs have already been reported for an agent so a resumed agent reports
only its new invocation while still showing its lifetime total.

The hook never blocks. It appends a readable audit line, returns a systemMessage
for the terminal, and writes a compact status-line message as a UI fallback.
"""

import datetime
import hashlib
import json
import os
import re
import sys
import tempfile
from collections.abc import Iterable
from typing import Any

LOG_PATH = os.path.expanduser(
    os.environ.get(
        "CLAUDE_SUBAGENT_USAGE_LOG",
        "~/.claude/hooks/subagent-usage-v2.log",
    )
)
LAST_PATH = os.path.expanduser(
    os.environ.get(
        "CLAUDE_SUBAGENT_LAST",
        "~/.claude/hooks/subagent-last.txt",
    )
)
STATE_DIR = os.path.expanduser(
    os.environ.get(
        "CLAUDE_SUBAGENT_USAGE_STATE_DIR",
        "~/.claude/hooks/.subagent-usage-state",
    )
)

PARTS = (
    "input",
    "cache_write_5m",
    "cache_write_1h",
    "cache_read",
    "output",
)

# USD per million tokens. This is an API-price estimate, not billing data.
MODEL_RATES = {
    "claude-sonnet-5": {
        "input": 2.0,
        "cache_write_5m": 2.5,
        "cache_write_1h": 4.0,
        "cache_read": 0.2,
        "output": 10.0,
    },
    "claude-opus-5": {
        "input": 5.0,
        "cache_write_5m": 6.25,
        "cache_write_1h": 10.0,
        "cache_read": 0.5,
        "output": 25.0,
    },
    "claude-haiku-4-5": {
        "input": 1.0,
        "cache_write_5m": 1.25,
        "cache_write_1h": 2.0,
        "cache_read": 0.1,
        "output": 5.0,
    },
}


def empty_parts() -> dict[str, int]:
    return {key: 0 for key in PARTS}


def compact(number: float) -> str:
    if number >= 1_000_000:
        return f"{number / 1_000_000:.1f}m"
    if number >= 1000:
        return f"{number / 1000:.1f}k"
    return str(int(number))


def safe_text(value: Any, default: str = "unknown") -> str:
    if not isinstance(value, str) or not value:
        return default
    return re.sub(r"[^A-Za-z0-9_.:+<>=/-]", "?", value)[:120]


def effort_level(value: Any) -> str | None:
    if isinstance(value, str) and value:
        return value
    if isinstance(value, dict):
        level = value.get("level")
        if isinstance(level, str) and level:
            return level
    return None


def usage_parts(usage: dict[str, Any]) -> dict[str, int]:
    parts = empty_parts()
    parts["input"] = usage.get("input_tokens") or 0
    parts["cache_read"] = usage.get("cache_read_input_tokens") or 0
    parts["output"] = usage.get("output_tokens") or 0

    created = usage.get("cache_creation")
    if isinstance(created, dict):
        parts["cache_write_5m"] = created.get("ephemeral_5m_input_tokens") or 0
        parts["cache_write_1h"] = created.get("ephemeral_1h_input_tokens") or 0
    else:
        parts["cache_write_5m"] = usage.get("cache_creation_input_tokens") or 0
    return parts


def read_transcript(path: str) -> dict[str, dict[str, Any]]:
    messages: dict[str, dict[str, Any]] = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue

            message = record.get("message")
            if not isinstance(message, dict):
                continue
            usage = message.get("usage")
            if not isinstance(usage, dict):
                continue

            message_id = message.get("id")
            if not isinstance(message_id, str) or not message_id:
                message_id = record.get("requestId") or record.get("uuid")
            if not isinstance(message_id, str) or not message_id:
                continue
            if message_id in messages:
                continue

            messages[message_id] = {
                "model": safe_text(message.get("model")),
                "effort": safe_text(effort_level(record.get("effort")), "unknown"),
                "parts": usage_parts(usage),
            }
    return messages


def read_json(path: str) -> dict[str, Any]:
    try:
        with open(path, encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def requested_model(parent_path: str, tool_use_id: Any) -> str:
    if not isinstance(tool_use_id, str) or not tool_use_id:
        return "unknown"
    try:
        handle = open(os.path.expanduser(parent_path), encoding="utf-8")
    except OSError:
        return "unknown"

    with handle:
        for line in handle:
            try:
                record = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            message = record.get("message")
            content = message.get("content") if isinstance(message, dict) else None
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") != "tool_use" or block.get("name") != "Agent":
                    continue
                if block.get("id") != tool_use_id:
                    continue
                tool_input = block.get("input")
                if not isinstance(tool_input, dict):
                    return "<omitted>"
                return safe_text(tool_input.get("model"), "<omitted>")
    return "unknown"


def state_key(agent_id: Any, transcript_path: str) -> str:
    if isinstance(agent_id, str) and re.fullmatch(r"[A-Za-z0-9_-]+", agent_id):
        return agent_id
    return hashlib.sha256(transcript_path.encode("utf-8")).hexdigest()[:24]


def load_seen(path: str) -> set[str]:
    value = read_json(path).get("message_ids")
    if not isinstance(value, list):
        return set()
    return {item for item in value if isinstance(item, str)}


def save_seen(path: str, message_ids: Iterable[str]) -> None:
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        prefix="usage-",
        suffix=".json",
        dir=os.path.dirname(path),
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump({"message_ids": sorted(message_ids)}, handle)
            handle.write("\n")
        os.replace(temporary, path)
    except OSError:
        try:
            os.unlink(temporary)
        except OSError:
            pass


def selected_messages(
    messages: dict[str, dict[str, Any]],
    message_ids: Iterable[str],
) -> list[dict[str, Any]]:
    selected = set(message_ids)
    return [message for key, message in messages.items() if key in selected]


def total_parts(messages: Iterable[dict[str, Any]]) -> dict[str, int]:
    total = empty_parts()
    for message in messages:
        parts = message["parts"]
        for key in PARTS:
            total[key] += parts[key]
    return total


def ordered_values(messages: Iterable[dict[str, Any]], key: str) -> list[str]:
    values: list[str] = []
    for message in messages:
        value = message[key]
        if value != "unknown" and (not values or values[-1] != value):
            values.append(value)
    return values


def rates_for(model: str) -> dict[str, float] | None:
    for prefix, rates in MODEL_RATES.items():
        if model.startswith(prefix):
            return rates
    return None


def estimated_cost(messages: Iterable[dict[str, Any]]) -> float | None:
    cost = 0.0
    known = False
    for message in messages:
        rates = rates_for(message["model"])
        if rates is None:
            continue
        known = True
        cost += sum(message["parts"][key] * rates[key] for key in PARTS) / 1_000_000
    return cost if known else None


def parts_text(parts: dict[str, int]) -> str:
    written = parts["cache_write_5m"] + parts["cache_write_1h"]
    return (
        f"in={compact(parts['input'])} write={compact(written)} "
        f"cached={compact(parts['cache_read'])} out={compact(parts['output'])}"
    )


def cost_text(cost: float | None) -> str:
    return "n/a" if cost is None else f"${cost:.4f}"


def append_line(path: str, line: str) -> None:
    try:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError:
        pass


def write_last(line: str) -> None:
    try:
        with open(LAST_PATH, "w", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError:
        pass


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        transcript_path = payload.get("agent_transcript_path")
        if not isinstance(transcript_path, str) or not transcript_path:
            print("{}")
            return
        transcript_path = os.path.expanduser(transcript_path)

        messages = read_transcript(transcript_path)
        if not messages:
            print("{}")
            return

        key = state_key(payload.get("agent_id"), transcript_path)
        state_path = os.path.join(STATE_DIR, key + ".json")
        previously_seen = load_seen(state_path)
        current_ids = set(messages) - previously_seen
        if not current_ids:
            print("{}")
            return

        current = selected_messages(messages, current_ids)
        lifetime = list(messages.values())

        meta_path = os.path.splitext(transcript_path)[0] + ".meta.json"
        meta = read_json(meta_path)
        agent_type = safe_text(payload.get("agent_type") or meta.get("agentType"), "subagent")
        policy = safe_text(meta.get("model"))
        requested = requested_model(
            str(payload.get("transcript_path") or ""),
            meta.get("toolUseId"),
        )
        models = ordered_values(current, "model") or ordered_values(lifetime, "model")
        efforts = ordered_values(current, "effort") or ordered_values(lifetime, "effort")

        current_parts = total_parts(current)
        lifetime_parts = total_parts(lifetime)
        current_cost = estimated_cost(current)
        lifetime_cost = estimated_cost(lifetime)

        summary = (
            f"subagent done: {agent_type} requested={requested} policy={policy} "
            f"actual={'->'.join(models) or 'unknown'} "
            f"effort={'->'.join(efforts) or 'unknown'} "
            f"run={cost_text(current_cost)} ({parts_text(current_parts)}) "
            f"lifetime={cost_text(lifetime_cost)} ({parts_text(lifetime_parts)})"
        )
        stamp = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
        session = safe_text(str(payload.get("session_id") or "")[:8], "--------")
        append_line(LOG_PATH, f"{stamp} {session} {summary}")
        write_last(
            f"agent {agent_type} {'->'.join(models) or 'unknown'}/"
            f"{'->'.join(efforts) or 'unknown'} {cost_text(current_cost)} "
            f"{parts_text(current_parts)}"
        )
        save_seen(state_path, messages.keys())
        print(json.dumps({"systemMessage": summary}))
    except Exception:
        # A reporting failure must never keep the subagent or parent running.
        print("{}")


if __name__ == "__main__":
    main()

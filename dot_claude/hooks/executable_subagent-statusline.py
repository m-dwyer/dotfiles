#!/usr/bin/env python3
"""Render live subagent rows with the model recorded in their transcript."""

import datetime
import hashlib
import json
import os
import re
import sys
import tempfile
import time
from typing import Any

CACHE_DIR = os.path.expanduser(
    os.environ.get(
        "CLAUDE_SUBAGENT_STATUS_CACHE_DIR",
        "~/.claude/hooks/.subagent-status-cache",
    )
)
POLICY = {
    "scout": "sonnet",
    "coder": "sonnet",
    "reviewer": "sonnet",
    "planner": "opus",
    "Explore": "sonnet",
    "Plan": "sonnet",
    "general-purpose": "sonnet",
}


def safe_key(value: Any) -> str:
    if isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_-]+", value):
        return value
    return hashlib.sha256(str(value).encode("utf-8")).hexdigest()[:24]


def read_json(path: str) -> dict[str, Any]:
    try:
        with open(path, encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def latest_model(path: str) -> str | None:
    model: str | None = None
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                try:
                    record = json.loads(line)
                except (json.JSONDecodeError, ValueError):
                    continue
                message = record.get("message")
                recorded = message.get("model") if isinstance(message, dict) else None
                if isinstance(recorded, str) and recorded:
                    model = recorded
    except OSError:
        return None
    return model


def task_name(task: dict[str, Any]) -> str:
    for key in ("name", "type", "label"):
        value = task.get(key)
        if isinstance(value, str) and value:
            return value
    return "subagent"


def find_agent_files(
    directory: str,
    task: dict[str, Any],
) -> tuple[str | None, dict[str, Any]]:
    task_id = str(task.get("id") or "")
    stems = [task_id]
    if task_id and not task_id.startswith("agent-"):
        stems.insert(0, "agent-" + task_id)
    for stem in stems:
        transcript = os.path.join(directory, stem + ".jsonl")
        meta = read_json(os.path.join(directory, stem + ".meta.json"))
        if os.path.isfile(transcript):
            return transcript, meta

    description = task.get("description")
    name = task_name(task)
    matches: list[tuple[float, str, dict[str, Any]]] = []
    try:
        entries = os.scandir(directory)
    except OSError:
        return None, {}
    with entries:
        for entry in entries:
            if not entry.name.endswith(".meta.json") or not entry.is_file():
                continue
            meta = read_json(entry.path)
            if not meta:
                continue
            id_matches = meta.get("toolUseId") == task_id
            description_matches = (
                isinstance(description, str)
                and meta.get("description") == description
            )
            if not id_matches and not description_matches:
                continue
            transcript = entry.path.removesuffix(".meta.json") + ".jsonl"
            if os.path.isfile(transcript):
                matches.append((entry.stat().st_mtime, transcript, meta))
    if not matches:
        return None, {}
    _, transcript, meta = max(matches, key=lambda match: match[0])
    return transcript, meta


def resolved_policy(alias: Any) -> str | None:
    if not isinstance(alias, str) or not alias:
        return None
    if alias == "sonnet":
        return os.environ.get("ANTHROPIC_DEFAULT_SONNET_MODEL", "sonnet")
    if alias == "opus":
        return os.environ.get("ANTHROPIC_DEFAULT_OPUS_MODEL", "opus")
    if alias == "haiku":
        return os.environ.get("ANTHROPIC_DEFAULT_HAIKU_MODEL", "haiku")
    return alias


def compact_tokens(value: Any) -> str:
    if not isinstance(value, (int, float)):
        return ""
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}m"
    if value >= 1000:
        return f"{value / 1000:.1f}k"
    return str(int(value))


def elapsed(value: Any) -> str:
    started: float | None = None
    if isinstance(value, (int, float)):
        started = float(value)
        if started > 10_000_000_000:
            started /= 1000
    elif isinstance(value, str):
        try:
            started = datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            pass
    if started is None:
        return ""
    seconds = max(0, int(time.time() - started))
    minutes, seconds = divmod(seconds, 60)
    if minutes:
        return f"{minutes}m {seconds}s"
    return f"{seconds}s"


def render(task: dict[str, Any], model: str, columns: int, agent_type: str) -> str:
    name = agent_type
    description = task.get("description")
    description = description if isinstance(description, str) else ""
    left_prefix = f"{name} · {model}"
    right_parts = [
        part
        for part in (
            elapsed(task.get("startTime")),
            ("↓ " + compact_tokens(task.get("tokenCount")) + " tokens")
            if compact_tokens(task.get("tokenCount"))
            else "",
        )
        if part
    ]
    right = " · ".join(right_parts)
    reserved = len(left_prefix) + len(right) + (4 if description else 2)
    available = max(0, columns - reserved)
    if len(description) > available:
        description = description[: max(0, available - 1)] + ("…" if available else "")
    left = left_prefix + (("  " + description) if description else "")
    if not right:
        return left
    return left + (" " * max(1, columns - len(left) - len(right))) + right


def save_cache(path: str, cache: dict[str, Any]) -> None:
    try:
        os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(
            prefix="status-", suffix=".json", dir=os.path.dirname(path), text=True
        )
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(cache, handle)
            handle.write("\n")
        os.replace(temporary, path)
    except OSError:
        try:
            os.unlink(temporary)
        except (OSError, UnboundLocalError):
            pass


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    tasks = payload.get("tasks")
    if not isinstance(tasks, list):
        return
    transcript_path = payload.get("transcript_path")
    if not isinstance(transcript_path, str) or not transcript_path:
        return
    expanded_transcript = os.path.expanduser(transcript_path)
    subagents = os.path.join(os.path.splitext(expanded_transcript)[0], "subagents")
    session = safe_key(payload.get("session_id"))
    cache_path = os.path.join(CACHE_DIR, session + ".json")
    cache = read_json(cache_path)
    columns = payload.get("columns")
    columns = int(columns) if isinstance(columns, (int, float)) else 100

    changed = False
    for raw_task in tasks:
        if not isinstance(raw_task, dict) or task_name(raw_task) == "main":
            continue
        task_id = str(raw_task.get("id") or "")
        if not task_id:
            continue
        cached = cache.get(task_id)
        cached = cached if isinstance(cached, dict) else {}
        transcript = cached.get("transcript")
        meta: dict[str, Any] = {}
        if not isinstance(transcript, str) or not os.path.isfile(transcript):
            transcript, meta = find_agent_files(subagents, raw_task)
            if transcript:
                cached["transcript"] = transcript
                changed = True
        if not meta and isinstance(transcript, str):
            meta = read_json(os.path.splitext(transcript)[0] + ".meta.json")
        agent_type = cached.get("agent_type")
        if not isinstance(agent_type, str) or not agent_type:
            recorded_type = meta.get("agentType") if meta else None
            agent_type = recorded_type if isinstance(recorded_type, str) else task_name(raw_task)
            if recorded_type:
                cached["agent_type"] = agent_type
                changed = True
        model = cached.get("model")
        if not isinstance(model, str) or not model:
            model = latest_model(transcript) if isinstance(transcript, str) else None
            if model:
                cached["model"] = model
                changed = True
        if not model:
            alias = meta.get("model") if meta else POLICY.get(agent_type)
            policy = resolved_policy(alias)
            model = f"{policy} (policy)" if policy else "model pending"
        cache[task_id] = cached
        print(
            json.dumps(
                {
                    "id": task_id,
                    "content": render(raw_task, model, columns, agent_type),
                },
                ensure_ascii=False,
            )
        )

    if changed:
        save_cache(cache_path, cache)


if __name__ == "__main__":
    main()

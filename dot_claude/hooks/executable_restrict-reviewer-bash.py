#!/usr/bin/env python3
"""Fail-closed Bash policy for the read-only reviewer agent."""

import json
import re
import shlex
import sys

ALLOWED_SUBCOMMANDS = {
    "blame",
    "diff",
    "diff-files",
    "diff-index",
    "diff-tree",
    "log",
    "ls-files",
    "ls-tree",
    "merge-base",
    "rev-parse",
    "show",
    "status",
}

ALLOWED_GLOBAL_FLAGS = {
    "--literal-pathspecs",
    "--no-optional-locks",
    "--no-pager",
}

FORBIDDEN_ARGUMENTS = {
    "--ext-diff",
    "--no-index",
    "--paginate",
    "--textconv",
    "-p",
}


def deny(reason: str) -> None:
    print(f"Blocked reviewer Bash command: {reason}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        deny("hook input was not valid JSON")

    tool_input = payload.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not isinstance(command, str) or not command.strip():
        deny("missing command")

    if re.search(r"[\n;&|<>`]", command) or "$(" in command:
        deny("shell operators, substitutions, and redirections are not allowed")

    try:
        words = shlex.split(command, posix=True)
    except ValueError:
        deny("command could not be parsed")

    if not words or words[0] != "git":
        deny("only read-only Git commands are allowed")

    index = 1
    saw_directory = False
    while index < len(words):
        word = words[index]
        if word in ALLOWED_GLOBAL_FLAGS:
            index += 1
            continue
        if word == "-C" and not saw_directory:
            if index + 1 >= len(words):
                deny("git -C requires a directory")
            saw_directory = True
            index += 2
            continue
        break

    if index >= len(words) or words[index] not in ALLOWED_SUBCOMMANDS:
        deny("Git subcommand is not on the reviewer allowlist")

    for word in words[index + 1 :]:
        if word in FORBIDDEN_ARGUMENTS:
            deny(f"{word} is not allowed")
        if word == "-c" or word.startswith("-c="):
            deny("Git configuration overrides are not allowed")
        if word.startswith("--config-env") or word.startswith("--exec-path"):
            deny("Git execution/configuration overrides are not allowed")
        if word.startswith("--output"):
            deny("commands may not write output files")

    print("{}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""MessageDisplay hook: rewrite some of Claude's characteristic filler words
before they're displayed. Display-only — the real transcript keeps the original.

Add future swaps by extending REPLACEMENTS. Keep in mind:
  - 'finagle' is a VERB, so only map other verbs to it or the grammar breaks.
  - Matching runs on the streamed `delta` chunk, so a swap only lands when the
    whole word arrives in one chunk. Fine for a vanity swap; expect occasional misses.
  - Longest keys are matched first, so multi-word phrases win over single words.
"""
import json
import re
import sys

# phrase -> replacement. Case-insensitive, word-boundary matched.
REPLACEMENTS = {
    # verbs -> 'finagle' (all grammatical because finagle is itself a verb)
    "leverage": "finagle",
    "delve": "finagle",
    "streamline": "finagle",
    # room to grow, e.g.:
    # "you're absolutely right": "good point",
    # "it's worth noting that": "note:",
}

# Match longest keys first so phrases beat the single words inside them.
_KEYS = sorted(REPLACEMENTS, key=len, reverse=True)
_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(k) for k in _KEYS) + r")\b",
    re.IGNORECASE,
)
# Look up replacements case-insensitively.
_LOOKUP = {k.lower(): v for k, v in REPLACEMENTS.items()}


def main() -> None:
    data = json.load(sys.stdin)
    text = data.get("delta") or ""
    if _KEYS:
        text = _PATTERN.sub(lambda m: _LOOKUP[m.group(0).lower()], text)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "MessageDisplay",
            "displayContent": text,
        }
    }))


if __name__ == "__main__":
    main()

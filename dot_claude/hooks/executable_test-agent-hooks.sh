#!/bin/bash
set -eu

hooks_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

assert_json() {
  label=$1 expected=$2 actual=$3
  if ! printf '%s\n' "$actual" | jq -e "$expected" >/dev/null; then
    printf 'FAIL: %s\n%s\n' "$label" "$actual" >&2
    exit 1
  fi
}

if ! grep -q '^maxTurns: 24$' "$hooks_dir/../agents/reviewer.md"; then
  printf 'FAIL: reviewer maxTurns is not 24\n' >&2
  exit 1
fi

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
config_dir="$fixture_dir/config"
project_dir="$fixture_dir/project"
mkdir -p "$config_dir/agents" "$project_dir/.claude/agents"
assert_pinnable_model() {
  assert_json "$1 model schema" '.hookSpecificOutput.updatedInput.model | IN("sonnet", "opus", "haiku", "fable")' "$2"
}
pin() {
  output=$(printf '%s\n' "$1" | env CLAUDE_CONFIG_DIR="$config_dir" "$hooks_dir/pin-subagent-model.py")
  if ! printf '%s\n' "$1" | jq -e '.tool_input.subagent_type == "fork"' >/dev/null; then
    assert_pinnable_model "pinnable hook result" "$output"
  fi
  printf '%s\n' "$output"
}

output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"coder","description":"Rename rack shell"}}')
assert_json "unknown custom defaults to sonnet" '(.systemMessage | contains("declared=fallback · enforced=sonnet")) and .hookSpecificOutput.updatedInput.model == "sonnet"' "$output"
output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"sonnet"}}')
assert_json "pinnable calls always update input" '.hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

for pair in \
  'claude-sonnet-5 sonnet' \
  'claude-opus-5 opus' \
  'claude-haiku-4-5-20251001 haiku' \
  'sonnet sonnet' \
  'opus opus' \
  'haiku haiku' \
  'fable fable'; do
  set -- $pair
  declared=$1 enforced=$2
  cat >"$project_dir/.claude/agents/mapped-$enforced.md" <<EOF
---
name: mapped-$enforced
model: $declared
---
EOF
  output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"mapped-'"$enforced"'","description":"Mapping","model":"sonnet"}}')
  assert_json "explicit $declared mapping" '(.systemMessage | contains("declared='"$declared"' · enforced='"$enforced"'")) and .hookSpecificOutput.updatedInput.model == "'"$enforced"'"' "$output"
done

cat >"$config_dir/agents/different-file.md" <<'EOF'
---
name: precedence-worker
model: claude-sonnet-5
---
EOF
cat >"$project_dir/.claude/agents/near.md" <<'EOF'
---
name: precedence-worker
model: claude-opus-5
---
EOF
output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"precedence-worker","description":"Precedence","model":"sonnet"}}')
assert_json "project definitions precede user definitions" '.hookSpecificOutput.updatedInput.model == "opus"' "$output"
output=$(pin '{"cwd":"/does/not/exist","tool_input":{"subagent_type":"precedence-worker","description":"Invalid cwd","model":"opus"}}')
assert_json "invalid cwd still uses user agents" '.hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

for kind in unsupported old-haiku fake-fable case-variant empty structured malformed; do
  name="broken-$kind"
  case "$kind" in
    unsupported) model="claude-unsupported-5"; body="---\nname: $name\nmodel: $model\n---" ;;
    old-haiku) model="claude-haiku-5"; body="---\nname: $name\nmodel: $model\n---" ;;
    fake-fable) model="claude-fable-5"; body="---\nname: $name\nmodel: $model\n---" ;;
    case-variant) model="Sonnet"; body="---\nname: $name\nmodel: $model\n---" ;;
    empty) model=""; body="---\nname: $name\nmodel: \n---" ;;
    structured) model="[opus]"; body="---\nname: $name\nmodel: $model\n---" ;;
    malformed) model="opus"; body="---\nname: $name\nmodel: $model" ;;
  esac
  printf '%b\n' "$body" >"$project_dir/.claude/agents/$name.md"
  output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"'"$name"'","description":"Broken","model":"opus"}}')
  assert_json "$kind matching custom fails closed" '(.systemMessage | contains("enforced=sonnet")) and .hookSpecificOutput.updatedInput.model == "sonnet"' "$output"
  case "$kind" in
    unsupported|old-haiku|fake-fable|case-variant)
      assert_json "$kind reports its declaration" '.systemMessage | contains("declared='"$model"' · enforced=sonnet")' "$output"
      ;;
    *)
      assert_json "$kind reports fallback declaration" '.systemMessage | contains("declared=fallback · enforced=sonnet")' "$output"
      ;;
  esac
done

cat >"$project_dir/.claude/agents/duplicate-valid-invalid-valid.md" <<'EOF'
---
name: duplicate-valid-invalid
model: opus
---
EOF
cat >"$project_dir/.claude/agents/duplicate-valid-invalid-invalid.md" <<'EOF'
---
name: duplicate-valid-invalid
model: [sonnet]
---
EOF
output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"duplicate-valid-invalid","description":"Duplicate","model":"opus"}}')
assert_json "valid and invalid duplicate definitions fail closed" '.hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

cat >"$project_dir/.claude/agents/duplicate-valid-one.md" <<'EOF'
---
name: duplicate-valid
model: opus
---
EOF
cat >"$project_dir/.claude/agents/duplicate-valid-two.md" <<'EOF'
---
name: duplicate-valid
model: haiku
---
EOF
output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"duplicate-valid","description":"Duplicate","model":"opus"}}')
assert_json "multiple valid duplicate definitions fail closed" '.hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

for type in Explore Plan general-purpose; do
  output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"'"$type"'","description":"Builtin","model":"opus"}}')
  assert_json "builtin $type" '(.systemMessage | contains("declared=fallback · enforced=sonnet")) and .hookSpecificOutput.updatedInput.model == "sonnet"' "$output"
done
output=$(pin '{"cwd":"'"$project_dir"'","tool_input":{"subagent_type":"fork","description":"Continue investigation","model":"opus"}}')
assert_json "fork inherits" '(.systemMessage | contains("declared=fallback · enforced=inherit")) and (has("hookSpecificOutput") | not)' "$output"
output=$(pin '{"tool_input":{"subagent_type":"unknown-agent","description":"Unknown","model":"opus"}}')
assert_json "unknown type forces sonnet" '.hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

# Import the hook's authoritative mapping, then verify every managed agent
# declares one of its exact keys.  This intentionally does not duplicate it.
if ! python3 - "$hooks_dir/pin-subagent-model.py" "$hooks_dir/../agents" <<'PY'
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("pin_subagent_model", sys.argv[1])
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
for path in sorted(Path(sys.argv[2]).glob("*.md")):
    _, model, valid = module.frontmatter(path)
    if not valid or model not in module.FRONTMATTER_MODEL_ALIASES:
        raise SystemExit(f"unmapped managed agent model: {path}: {model!r}")
PY
then
  printf 'FAIL: managed agent frontmatter model is not explicitly mapped\n' >&2
  exit 1
fi

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"sonnet"},"tool_response":{"agentType":"coder","resolvedModel":"claude-sonnet-5","content":[{"type":"text","text":"Finished."}]}}' | "$hooks_dir/report-agent-result.py")
assert_json "completed model result" '.systemMessage == "model result · coder · task=Rename rack shell · actual=claude-sonnet-5 · outcome=complete"' "$output"
output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"sonnet"},"tool_response":{"agentType":"coder","resolvedModel":"claude-sonnet-5","content":[{"type":"text","text":"NOTE: this agent stopped at its 24-turn limit before finishing."}]}}' | "$hooks_dir/report-agent-result.py")
assert_json "capped model result" '.systemMessage == "model result · coder · task=Rename rack shell · actual=claude-sonnet-5 · outcome=partial:turn-limit"' "$output"
output=$(printf '%s\n' 'not-json' | "$hooks_dir/report-agent-result.py")
assert_json "malformed result input" '. == {}' "$output"

cat >"$fixture_dir/agent-test.jsonl" <<'EOF'
{"message":{"id":"msg-1","model":"claude-sonnet-5","usage":{"input_tokens":2,"cache_read_input_tokens":10,"output_tokens":2}},"effort":"low"}
{"message":{"id":"msg-1","model":"claude-sonnet-5","usage":{"input_tokens":2,"cache_read_input_tokens":10,"output_tokens":97}},"effort":"low"}
EOF
output=$(printf '%s\n' "{\"agent_transcript_path\":\"$fixture_dir/agent-test.jsonl\",\"transcript_path\":\"$fixture_dir/parent.jsonl\",\"agent_id\":\"test-agent\",\"agent_type\":\"coder\",\"session_id\":\"test-session\"}" | env CLAUDE_SUBAGENT_USAGE_LOG="$fixture_dir/usage.log" CLAUDE_SUBAGENT_LAST_DIR="$fixture_dir/last" CLAUDE_SUBAGENT_USAGE_STATE_DIR="$fixture_dir/state" "$hooks_dir/report-subagent-usage.py")
assert_json "final repeated-message usage" '.systemMessage | contains("out=97")' "$output"
assert_json "per-session status state" '.text | startswith("coder · actual=claude-sonnet-5 · effort=low")' "$(cat "$fixture_dir/last/test-session.json")"
mkdir -p "$fixture_dir/home/.claude/hooks/subagent-last"
cp "$fixture_dir/last/test-session.json" "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json"
status=$(printf '%s\n' '{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"workspace":{"project_dir":"/tmp/project"},"session_id":"test-session"}' | HOME="$fixture_dir/home" bash "$hooks_dir/../statusline-command.sh")
case "$status" in *"last agent · coder · actual=claude-sonnet-5"*) ;; *) printf 'FAIL: fresh session status\n%s\n' "$status" >&2; exit 1 ;; esac
jq '.updated_at = 0' "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json" >"$fixture_dir/expired.json"
mv "$fixture_dir/expired.json" "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json"
status=$(printf '%s\n' '{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"workspace":{"project_dir":"/tmp/project"},"session_id":"test-session"}' | HOME="$fixture_dir/home" bash "$hooks_dir/../statusline-command.sh")
case "$status" in *"last agent"*) printf 'FAIL: expired session status\n%s\n' "$status" >&2; exit 1 ;; *) ;; esac

mkdir -p "$fixture_dir/project/session/subagents"
subagents="$fixture_dir/project/session/subagents"
status_payload() {
  printf '{"session_id":"%s","transcript_path":"%s/project/session.jsonl","columns":120,"tasks":[{"id":"%s","name":"local_agent","description":"Task"}]}' "$1" "$fixture_dir" "$2"
}
cat >"$subagents/agent-actual.meta.json" <<'EOF'
{"agentType":"scout","toolUseId":"actual","model":"metadata-model"}
EOF
cat >"$subagents/agent-actual.jsonl" <<'EOF'
{"message":{"model":"actual-model"}}
EOF
output=$(status_payload actual actual | env CLAUDE_SUBAGENT_STATUS_CACHE_DIR="$fixture_dir/cache-actual" "$hooks_dir/subagent-statusline.py")
assert_json "actual transcript beats metadata" '.content | contains("scout · actual-model")' "$output"
cat >"$subagents/agent-meta.meta.json" <<'EOF'
{"agentType":"scout","toolUseId":"meta","model":"metadata-model"}
EOF
: >"$subagents/agent-meta.jsonl"
output=$(status_payload meta meta | env CLAUDE_SUBAGENT_STATUS_CACHE_DIR="$fixture_dir/cache-meta" "$hooks_dir/subagent-statusline.py")
assert_json "metadata model without actual" '.content | contains("scout · metadata-model")' "$output"
cat >"$subagents/agent-pending.meta.json" <<'EOF'
{"agentType":"scout","toolUseId":"pending"}
EOF
: >"$subagents/agent-pending.jsonl"
mkdir -p "$fixture_dir/cache-pending"
printf '%s\n' '{"pending":{"model":"sonnet"}}' >"$fixture_dir/cache-pending/pending-session.json"
output=$(status_payload pending pending | env CLAUDE_SUBAGENT_STATUS_CACHE_DIR="$fixture_dir/cache-pending" "$hooks_dir/subagent-statusline.py")
assert_json "no actual or metadata is pending" '(.content | contains("scout · model pending")) and (.content | contains("(policy)") | not)' "$output"

printf 'All agent hook tests passed.\n'

#!/bin/bash
set -eu

hooks_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

assert_json() {
  label=$1
  expected=$2
  actual=$3
  if ! printf '%s\n' "$actual" | jq -e "$expected" >/dev/null; then
    printf 'FAIL: %s\n%s\n' "$label" "$actual" >&2
    exit 1
  fi
}

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell"}}' | "$hooks_dir/pin-subagent-model.py")
assert_json "default model policy" '.systemMessage == "model policy · coder · task=Rename rack shell · requested=default · enforced=sonnet" and .hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"opus"}}' | "$hooks_dir/pin-subagent-model.py")
assert_json "explicit model override" '.systemMessage == "model policy · coder · task=Rename rack shell · requested=opus · enforced=sonnet" and .hookSpecificOutput.updatedInput.model == "sonnet"' "$output"

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"fork","description":"Continue investigation"}}' | "$hooks_dir/pin-subagent-model.py")
assert_json "inherited model" '.systemMessage == "model policy · fork · task=Continue investigation · requested=default · enforced=inherit" and (has("hookSpecificOutput") | not)' "$output"

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"sonnet"},"tool_response":{"agentType":"coder","resolvedModel":"claude-sonnet-5","content":[{"type":"text","text":"Finished."}]}}' | "$hooks_dir/report-agent-result.py")
assert_json "completed model result" '.systemMessage == "model result · coder · task=Rename rack shell · actual=claude-sonnet-5 · outcome=complete"' "$output"

output=$(printf '%s\n' '{"tool_input":{"subagent_type":"coder","description":"Rename rack shell","model":"sonnet"},"tool_response":{"agentType":"coder","resolvedModel":"claude-sonnet-5","content":[{"type":"text","text":"NOTE: this agent stopped at its 24-turn limit before finishing."}]}}' | "$hooks_dir/report-agent-result.py")
assert_json "capped model result" '.systemMessage == "model result · coder · task=Rename rack shell · actual=claude-sonnet-5 · outcome=partial:turn-limit"' "$output"

output=$(printf '%s\n' 'not-json' | "$hooks_dir/report-agent-result.py")
assert_json "malformed input" '. == {}' "$output"

fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
cat >"$fixture_dir/agent-test.jsonl" <<'EOF'
{"message":{"id":"msg-1","model":"claude-sonnet-5","usage":{"input_tokens":2,"cache_read_input_tokens":10,"output_tokens":3}},"effort":"low"}
{"message":{"id":"msg-1","model":"claude-sonnet-5","usage":{"input_tokens":2,"cache_read_input_tokens":10,"output_tokens":97}},"effort":"low"}
EOF
output=$(printf '%s\n' "{\"agent_transcript_path\":\"$fixture_dir/agent-test.jsonl\",\"transcript_path\":\"$fixture_dir/parent.jsonl\",\"agent_id\":\"test-agent\",\"agent_type\":\"coder\",\"session_id\":\"test-session\"}" | env CLAUDE_SUBAGENT_USAGE_LOG="$fixture_dir/usage.log" CLAUDE_SUBAGENT_LAST_DIR="$fixture_dir/last" CLAUDE_SUBAGENT_USAGE_STATE_DIR="$fixture_dir/state" "$hooks_dir/report-subagent-usage.py")
assert_json "final repeated-message usage" '.systemMessage | contains("out=97")' "$output"
assert_json "per-session status state" '.text | startswith("coder · actual=claude-sonnet-5 · effort=low")' "$(cat "$fixture_dir/last/test-session.json")"

mkdir -p "$fixture_dir/home/.claude/hooks/subagent-last"
cp "$fixture_dir/last/test-session.json" "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json"
status=$(printf '%s\n' '{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"workspace":{"project_dir":"/tmp/project"},"session_id":"test-session"}' | HOME="$fixture_dir/home" bash "$hooks_dir/../statusline-command.sh")
case "$status" in
  *"last agent · coder · actual=claude-sonnet-5"*) ;;
  *) printf 'FAIL: fresh session status\n%s\n' "$status" >&2; exit 1 ;;
esac

jq '.updated_at = 0' "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json" >"$fixture_dir/expired.json"
mv "$fixture_dir/expired.json" "$fixture_dir/home/.claude/hooks/subagent-last/test-session.json"
status=$(printf '%s\n' '{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"workspace":{"project_dir":"/tmp/project"},"session_id":"test-session"}' | HOME="$fixture_dir/home" bash "$hooks_dir/../statusline-command.sh")
case "$status" in
  *"last agent"*) printf 'FAIL: expired session status\n%s\n' "$status" >&2; exit 1 ;;
  *) ;;
esac

mkdir -p "$fixture_dir/project/session/subagents"
cat >"$fixture_dir/project/session/subagents/agent-live-scout.meta.json" <<'EOF'
{"agentType":"scout","description":"Map executor lane surface in C","model":"sonnet","toolUseId":"toolu-scout"}
EOF
cat >"$fixture_dir/project/session/subagents/agent-live-scout.jsonl" <<'EOF'
{"agentId":"live-scout","message":{"id":"msg-live","model":"claude-sonnet-5","usage":{"output_tokens":3}},"effort":"medium"}
EOF
output=$(printf '%s\n' "{\"session_id\":\"panel-test\",\"transcript_path\":\"$fixture_dir/project/session.jsonl\",\"columns\":120,\"tasks\":[{\"id\":\"main\",\"name\":\"main\",\"description\":\"Main\"},{\"id\":\"live-scout\",\"name\":\"local_agent\",\"type\":\"local_agent\",\"description\":\"Map executor lane surface in C\",\"tokenCount\":66900}] }" | env CLAUDE_SUBAGENT_STATUS_CACHE_DIR="$fixture_dir/panel-cache" "$hooks_dir/subagent-statusline.py")
assert_json "live subagent model" '.id == "live-scout" and (.content | contains("scout · claude-sonnet-5  Map executor lane surface in C")) and (.content | contains("↓ 66.9k tokens"))' "$output"
if printf '%s\n' "$output" | jq -e 'select(.id == "main")' >/dev/null; then
  printf 'FAIL: main row should keep default rendering\n%s\n' "$output" >&2
  exit 1
fi

printf 'All agent hook tests passed.\n'

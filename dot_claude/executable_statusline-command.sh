#!/bin/bash

# Compact Claude Code status line: active model/effort and context usage.
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "Claude"')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
percentage=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
project_dir=$(printf '%s' "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
agent_status=""
case "$session_id" in
  ""|*[!A-Za-z0-9_-]*) ;;
  *)
    agent_status_file="$HOME/.claude/hooks/subagent-last/$session_id.json"
    if [ -r "$agent_status_file" ]; then
      agent_updated=$(jq -r '.updated_at // 0' "$agent_status_file" 2>/dev/null)
      case "$agent_updated" in
        ""|*[!0-9]*) ;;
        *)
          agent_age=$(($(date +%s) - agent_updated))
          if [ "$agent_age" -ge 0 ] && [ "$agent_age" -le 300 ]; then
            agent_status=$(jq -r '.text // empty' "$agent_status_file" 2>/dev/null)
          fi
          ;;
      esac
    fi
    ;;
esac

# The status-line payload does not expose sandbox state. Resolve the scalar
# setting from the same common scopes, with the more specific scope winning.
sandbox_enabled="${CLAUDE_CODE_SANDBOXED:-}"
for settings_file in \
  "$HOME/.claude/settings.json" \
  "$project_dir/.claude/settings.json" \
  "$project_dir/.claude/settings.local.json"
do
  [ -f "$settings_file" ] || continue
  configured=$(jq -r '
    if .sandbox.enabled == true then "1"
    elif .sandbox.enabled == false then "0"
    else empty
    end
  ' "$settings_file" 2>/dev/null)
  [ -n "$configured" ] && sandbox_enabled="$configured"
done

environment=""
if [ "${IS_CONTAINER:-}" = "1" ]; then
  environment="\033[36m\033[0m"
fi
if [ "$sandbox_enabled" = "1" ]; then
  environment="${environment:+$environment }\033[33m\033[0m"
fi

if [ -n "$effort" ]; then
  identity="$model · $effort"
else
  identity="$model"
fi

bar_width=20
if [ -n "$percentage" ]; then
  percent_int=$(printf '%.0f' "$percentage")
  [ "$percent_int" -lt 0 ] && percent_int=0
  [ "$percent_int" -gt 100 ] && percent_int=100
  filled=$((percent_int * bar_width / 100))
  percent_label="${percent_int}%"
else
  percent_int=0
  filled=0
  percent_label="--%"
fi
empty=$((bar_width - filled))

filled_bar=""
empty_bar=""
i=0
while [ "$i" -lt "$filled" ]; do
  filled_bar="${filled_bar}█"
  i=$((i + 1))
done
i=0
while [ "$i" -lt "$empty" ]; do
  empty_bar="${empty_bar}░"
  i=$((i + 1))
done

if [ "$percent_int" -ge 80 ]; then
  color='\033[31m'
elif [ "$percent_int" -ge 60 ]; then
  color='\033[33m'
else
  color='\033[32m'
fi

printf '%b%s\033[1;36m%s\033[0m  %b%s%s\033[0m %s context%s%s\n' \
  "$environment" "${environment:+  }" "$identity" \
  "$color" "$filled_bar" "$empty_bar" "$percent_label" \
  "${agent_status:+  ·  last agent · }" "$agent_status"

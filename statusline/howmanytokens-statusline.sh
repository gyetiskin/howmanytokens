#!/bin/bash
# HowManyTokens bridge.
#
# Claude Code passes a JSON payload on stdin to the configured status line
# command. That payload carries the real subscription usage percentages under
# rate_limits.five_hour and rate_limits.seven_day. This script writes them to a
# file that HowManyTokens.app reads, and prints a short summary for the status
# line itself.
#
# The write is atomic — staged through a .tmp file and moved into place — so the
# app never reads a half-written file.

input=$(cat)
out="$HOME/.claude/howmanytokens-usage.json"

printf '%s' "$input" | /usr/bin/jq -c '{
  rate_limits: .rate_limits,
  captured_at: now
}' > "$out.tmp" 2>/dev/null && mv -f "$out.tmp" "$out"

# Status line output: five-hour and weekly usage, plus the model name.
printf '%s' "$input" | /usr/bin/jq -r '
  [ (.rate_limits.five_hour.used_percentage // empty | "5h \(round)%"),
    (.rate_limits.seven_day.used_percentage  // empty | "7d \(round)%"),
    (.model.display_name // empty)
  ] | map(select(. != null and . != "")) | join("  |  ")
' 2>/dev/null

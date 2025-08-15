#!/bin/bash
#!/bin/bash
# Process check helper
# Usage: pcheck.sh <name|command|external|url> <identifier>
# Prints matching PIDs (newline-separated).
# On invalid mode prints sentinel and exits non-zero.

set -o pipefail

sentinel="0123456789876543210"

check_by_name() {
  local pattern="$1"
  # Name match: keep as pgrep (process name). If you need full cmdline, use command mode.
  if command -v pgrep >/dev/null 2>&1; then
    pgrep "$pattern" || true
  else
    ps -A -o pid= -o comm= | awk -v pat="$pattern" '$0 ~ pat {print $1}'
  fi
}

check_by_command() {
  local pattern="$1"
  # Prefer pgrep -f for full command matches; fallback to ps+awk
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$pattern" || true
  else
    ps aux | grep -F "$pattern" | grep -v grep | awk '{print $2}'
  fi
}

check_by_external() {
  local cmd="$1"
  # WARNING: executes provided command. Use only with trusted inputs.
  eval "$cmd" 2>/dev/null || true
}

check_by_url() {
  local url_or_domain="$1"
  # TODO: Implement browser automation or system-wide filtering.
  # For now, no-op to maintain interface; returns empty.
  printf ""
}

mode="${1:-}"
data="${2:-}"

case "$mode" in
  name|Name|NAME)
    check_by_name "$data"
    ;;
  command|Command|COMMAND)
    check_by_command "$data"
    ;;
  external|External|EXTERNAL)
    check_by_external "$data"
    ;;
  url|Url|URL)
    check_by_url "$data"
    ;;
  *)
    printf "%s" "$sentinel"
    exit 2
    ;;
esac

exit 0

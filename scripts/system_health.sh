#!/usr/bin/env bash
# system_health.sh - simple server health check
# Exit codes: 0 = healthy, 1 = warning, 2 = critical
set -euo pipefail

CPU_T=90
MEM_T=85
DISK_T=80
JSON=0
LOG_FILE="${LOG_FILE:-./health_log.txt}"
MAX_BYTES=1048576   # rotate the log when it is bigger than 1 MB

usage() {
  cat <<USAGE
Usage: $0 [--cpu N] [--mem N] [--disk N] [--json] [--help]

  --cpu N    CPU warning threshold in percent   (default: $CPU_T)
  --mem N    Memory warning threshold in percent (default: $MEM_T)
  --disk N   Disk warning threshold in percent   (default: $DISK_T)
  --json     Write the log entry as JSON
  --help     Show this help

A value is CRITICAL when it is 10 points above its threshold (max 100).
Log file: \$LOG_FILE (default ./health_log.txt)
Exit codes: 0 healthy, 1 warning, 2 critical
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu)  CPU_T="${2:?--cpu needs a value}";  shift 2 ;;
    --mem)  MEM_T="${2:?--mem needs a value}";  shift 2 ;;
    --disk) DISK_T="${2:?--disk needs a value}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

for v in "$CPU_T" "$MEM_T" "$DISK_T"; do
  if ! [[ "$v" =~ ^[0-9]+$ ]]; then
    echo "Thresholds must be whole numbers, got: $v" >&2
    exit 64
  fi
done

STATUS=0

# check <name> <value> <threshold>  -> prints [WARNING]/[CRITICAL] and updates STATUS
check() {
  local name="$1" value="$2" threshold="$3" crit
  crit=$((threshold + 10))
  if [[ "$crit" -gt 100 ]]; then crit=100; fi
  if [[ "$value" -ge "$crit" ]]; then
    echo "[CRITICAL] $name is ${value}% (threshold ${threshold}%)"
    STATUS=2
  elif [[ "$value" -gt "$threshold" ]]; then
    echo "[WARNING] $name is ${value}% (threshold ${threshold}%)"
    if [[ "$STATUS" -lt 1 ]]; then STATUS=1; fi
  fi
}

# CPU usage over 1 second, from /proc/stat
cpu_usage() {
  local u n s i w q sq st idle1 idle2 total1 total2 dt
  read -r _ u n s i w q sq st _ < /proc/stat
  idle1=$((i + w)); total1=$((u + n + s + i + w + q + sq + st))
  sleep 1
  read -r _ u n s i w q sq st _ < /proc/stat
  idle2=$((i + w)); total2=$((u + n + s + i + w + q + sq + st))
  dt=$((total2 - total1))
  if [[ "$dt" -le 0 ]]; then echo 0; else echo $((100 * (dt - (idle2 - idle1)) / dt)); fi
}

CPU="$(cpu_usage)"
MEM="$(free | awk '/^Mem:/ {printf "%d", $3 * 100 / $2}')"
LOAD="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
TS="$(date '+%Y-%m-%d %H:%M:%S')"
HOST="$(hostname)"

check "CPU usage" "$CPU" "$CPU_T"
check "Memory usage" "$MEM" "$MEM_T"

# All mounted filesystems (skip virtual ones)
DISKS_TXT=""
DISKS_JSON=""
while read -r mount pct; do
  check "Disk usage on $mount" "$pct" "$DISK_T"
  DISKS_TXT+="${mount}:${pct}% "
  DISKS_JSON+="{\"mount\":\"${mount}\",\"used_percent\":${pct}},"
done < <(df -P -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1 {gsub("%","",$5); print $6, $5}')
DISKS_JSON="[${DISKS_JSON%,}]"

# Top 5 processes by memory (sed instead of head: avoids SIGPIPE with pipefail)
TOP_TXT=""
TOP_JSON=""
while read -r name pmem; do
  name="${name//\"/}"
  name="${name//\\/}"
  TOP_TXT+="${name}:${pmem}% "
  TOP_JSON+="{\"process\":\"${name}\",\"mem_percent\":${pmem}},"
done < <(ps -eo comm=,%mem= --sort=-%mem | sed -n '1,5p')
TOP_JSON="[${TOP_JSON%,}]"

case "$STATUS" in
  0) LABEL="OK" ;;
  1) LABEL="WARNING" ;;
  *) LABEL="CRITICAL" ;;
esac

# Simple log rotation: keep one old file
if [[ -f "$LOG_FILE" ]]; then
  size="$(stat -c %s "$LOG_FILE")"
  if [[ "$size" -gt "$MAX_BYTES" ]]; then mv "$LOG_FILE" "$LOG_FILE.1"; fi
fi

if [[ "$JSON" -eq 1 ]]; then
  ENTRY="{\"timestamp\":\"${TS}\",\"host\":\"${HOST}\",\"status\":\"${LABEL}\",\"cpu_percent\":${CPU},\"mem_percent\":${MEM},\"load_avg\":\"${LOAD}\",\"disks\":${DISKS_JSON},\"top_memory_processes\":${TOP_JSON}}"
else
  ENTRY="${TS} host=${HOST} status=${LABEL} cpu=${CPU}% mem=${MEM}% load=\"${LOAD}\" disks=\"${DISKS_TXT% }\" top5=\"${TOP_TXT% }\""
fi

echo "$ENTRY" >> "$LOG_FILE"
echo "$ENTRY"
exit "$STATUS"

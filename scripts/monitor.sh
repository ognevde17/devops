#!/usr/bin/env bash
# Exit: 0=active, 1=inactive/failed, 2=usage/dependency/read error, 3=unit missing.
set -uo pipefail
export LC_ALL=C
if [[ $# -ne 1 || ! "$1" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.@:-]*$ ]]; then
    echo 'Usage: monitor.sh SERVICE (for example: docker)' >&2
    exit 2
fi
service=$1
[[ "$service" == *.service ]] || service="${service}.service"
for dependency in systemctl journalctl grep gawk date; do
    command -v "$dependency" >/dev/null || { echo "Missing command: $dependency" >&2; exit 2; }
done
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
syslog=${SYSLOG_PATH:-/var/log/syslog}
now=${MONITOR_NOW:-$(date +%s)}
[[ "$now" =~ ^[0-9]+$ ]] || { echo 'MONITOR_NOW must be a Unix timestamp' >&2; exit 2; }
load_state=$(systemctl show --property=LoadState --value "$service") || exit 2
result=0
if [[ "$load_state" == not-found || -z "$load_state" ]]; then
    printf 'service=%s status=not-found\n' "$service"
    result=3
else
    status=$(systemctl is-active "$service")
    active_rc=$?
    printf 'service=%s status=%s\n' "$service" "${status:-unknown}"
    if [[ $active_rc -ne 0 ]]; then
        result=1
        echo 'Last 10 journal entries:'
        journalctl -u "$service" -n 10 --no-pager || result=2
    fi
fi
if [[ ! -r "$syslog" ]]; then
    printf 'Cannot read syslog: %s (try sudo)\n' "$syslog" >&2
    exit 2
fi
# grep exit 1 means no matches, not a read error. Do not hide exit 2.
count=$({
    grep -Ei '(^|[^[:alnum:]_])(error|err|failed|failure|fatal|panic|critical|crit|alert|emerg)([^[:alnum:]_]|$)' "$syslog"
    grep_rc=$?
    [[ $grep_rc -le 1 ]]
} | gawk -v now="$now" -f "$script_dir/count-errors.awk") || {
    echo 'Failed to read or parse syslog' >&2
    exit 2
}
printf 'syslog_errors_last_hour=%s\n' "$count"
printf 'window_epoch=[%s,%s] source=%s\n' "$((now - 3600))" "$now" "$syslog"
exit "$result"

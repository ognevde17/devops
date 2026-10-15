#!/usr/bin/env gawk -f
# Input: grep-filtered error lines. GNU awk is required for mktime().
# RFC3164 uses local time, RFC3339 uses its explicit UTC offset.
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
    for (i = 1; i <= 12; i++) months[names[i]] = i
    year = strftime("%Y", now)
    count = 0
    unparsed = 0
}
{
    stamp = -1
    if (match($0, /^([A-Z][a-z]{2}) +([0-9]{1,2}) +([0-9]{2}):([0-9]{2}):([0-9]{2}) /, a) && a[1] in months) {
        spec = sprintf("%d %d %d %d %d %d -1", year, months[a[1]], a[2], a[3], a[4], a[5])
        stamp = mktime(spec)
        # A December record on January 1 belongs to the previous year.
        if (stamp > now && strftime("%m", now) == "01" && months[a[1]] == 12)
            stamp = mktime(sprintf("%d %d %d %d %d %d -1", year - 1, months[a[1]], a[2], a[3], a[4], a[5]))
    } else if (match($0, /^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2}) /, a)) {
        stamp = mktime(sprintf("%d %d %d %d %d %d", a[1], a[2], a[3], a[4], a[5], a[6]), 1)
        if (a[8] != "Z") {
            offset = (substr(a[8], 2, 2) * 60 + substr(a[8], 5, 2)) * 60
            stamp += substr(a[8], 1, 1) == "+" ? -offset : offset
        }
    } else {
        unparsed++
    }
    if (stamp >= now - 3600 && stamp <= now) count++
}
END {
    print count
    if (unparsed) printf "WARNING: %d error-like log lines have unsupported timestamps\n", unparsed > "/dev/stderr"
}

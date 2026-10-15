"""Behavioral tests: actual monitor.sh + GNU awk, fake systemd commands only."""
import datetime as dt
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'monitor.sh'


class MonitorTests(unittest.TestCase):
    def run_monitor(self, log='', status='active', load='loaded', now='2026-01-01T00:30:00+00:00', args=None, readable=True):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'systemctl').write_text('''#!/bin/sh
case "$1" in
show) printf '%s\\n' "$FAKE_LOAD" ;;
is-active) printf '%s\\n' "$FAKE_STATUS"; [ "$FAKE_STATUS" = active ] ;;
*) exit 2 ;;
esac
''')
            (root / 'journalctl').write_text('#!/bin/sh\nprintf "journal called: %s\\n" "$*"\n')
            for p in ('systemctl', 'journalctl'):
                (root / p).chmod(0o755)
            if readable:
                (root / 'syslog').write_text(log)
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                       SYSLOG_PATH=str(root / 'syslog'), MONITOR_NOW=str(int(dt.datetime.fromisoformat(now).timestamp())),
                       FAKE_LOAD=load, FAKE_STATUS=status, TZ='UTC')
            return subprocess.run(['bash', str(SCRIPT), *(args if args is not None else ['docker'])],
                                  env=env, text=True, capture_output=True)

    def test_active_empty(self):
        r = self.run_monitor()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('syslog_errors_last_hour=0', r.stdout)

    def test_midnight_year_rollover_and_boundary(self):
        r = self.run_monitor('Dec 31 23:29:59 host app: error too old\n'
                             'Dec 31 23:30:00 host app: ERROR boundary\n'
                             'Jan  1 00:25:00 host app: failed now\n'
                             'Jan  1 00:31:00 host app: error future\n'
                             'Jan  1 00:25:00 host app: terror does not match\n')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('syslog_errors_last_hour=2', r.stdout)

    def test_iso_offsets(self):
        r = self.run_monitor('2026-01-01T03:15:00.123+03:00 h ERROR yes\n'
                             '2025-12-31T19:20:00-05:00 h error yes\n'
                             '2026-01-01T00:10:00Z h fatal yes\n'
                             '2025-12-31T22:00:00Z h error old\n')
        self.assertIn('syslog_errors_last_hour=3', r.stdout)

    def test_inactive_prints_journal(self):
        r = self.run_monitor(status='inactive')
        self.assertEqual(r.returncode, 1)
        self.assertIn('-u docker.service -n 10 --no-pager', r.stdout)

    def test_missing_unit(self):
        r = self.run_monitor(load='not-found')
        self.assertEqual(r.returncode, 3)
        self.assertIn('status=not-found', r.stdout)

    def test_unreadable_log(self):
        r = self.run_monitor(readable=False)
        self.assertEqual(r.returncode, 2)
        self.assertIn('Cannot read syslog', r.stderr)

    def test_invalid_argument(self):
        for args in ([], ['--help'], ['docker; id'], ['docker', 'ssh']):
            self.assertEqual(self.run_monitor(args=args).returncode, 2)

    def test_unknown_timestamp_warns(self):
        r = self.run_monitor('invalid-date host error broken timestamp\n')
        self.assertEqual(r.returncode, 0)
        self.assertIn('unsupported timestamps', r.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)

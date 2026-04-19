#!/usr/bin/env python3
"""
test_log_event.py — unit tests for log-event.py (stdlib unittest).

Run with: python3 hooks/scripts/test_log_event.py
"""

from __future__ import annotations

import json
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from typing import Optional, Union

# Path to log-event.py
LOG_EVENT_PY = pathlib.Path(__file__).parent / "log-event.py"


def _run_log_event(payload: Union[dict, str], hook_label: str = "postToolUse",
                   env: Optional[dict] = None, cwd: Optional[str] = None) -> subprocess.CompletedProcess:
    """Run log-event.py with the given payload on stdin."""
    stdin_data = json.dumps(payload) if isinstance(payload, dict) else payload
    run_env = {**os.environ}
    if env:
        run_env.update(env)
    return subprocess.run(
        [sys.executable, str(LOG_EVENT_PY), hook_label],
        input=stdin_data,
        capture_output=True,
        text=True,
        env=run_env,
        cwd=cwd,
    )


class TestLogEventCreatesRow(unittest.TestCase):
    """log-event.py must insert a row into events.db."""

    def test_log_event_creates_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / ".claude" / "observability" / "events.db"

            payload = {
                "session_id": "test-session-001",
                "hook_event_name": "PreToolUse",
                "tool_name": "Read",
                "tool_input": {"file_path": "/tmp/test.txt"},
                "cwd": tmp,
            }

            result = _run_log_event(
                payload,
                hook_label="preToolUse",
                env={"CLAUDE_PROJECT_DIR": tmp},
            )

            self.assertEqual(result.returncode, 0,
                             f"Expected exit 0, got {result.returncode}. stderr: {result.stderr}")
            self.assertTrue(db_path.exists(), f"DB not created at {db_path}")

            conn = sqlite3.connect(str(db_path))
            rows = conn.execute(
                "SELECT session_id, hook_event, tool_name FROM events WHERE session_id='test-session-001'"
            ).fetchall()
            conn.close()

            self.assertEqual(len(rows), 1, f"Expected 1 row, got {len(rows)}")
            self.assertEqual(rows[0][1], "PreToolUse")
            self.assertEqual(rows[0][2], "Read")


class TestLogEventRedactsSecrets(unittest.TestCase):
    """log-event.py must redact secrets from tool_input before storing."""

    def test_log_event_redacts_secrets(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / ".claude" / "observability" / "events.db"

            payload = {
                "session_id": "test-session-002",
                "hook_event_name": "PostToolUse",
                "tool_name": "Bash",
                "tool_input": {
                    "command": "export KEY=sk-ant-api03-XXXXXXXXXXXXXXXXXXXX1234567890abcdefghijklmnop"
                },
                "cwd": tmp,
            }

            result = _run_log_event(
                payload,
                hook_label="postToolUse",
                env={"CLAUDE_PROJECT_DIR": tmp},
            )

            self.assertEqual(result.returncode, 0,
                             f"Expected exit 0. stderr: {result.stderr}")
            self.assertTrue(db_path.exists(), "DB should be created")

            conn = sqlite3.connect(str(db_path))
            row = conn.execute(
                "SELECT tool_input_json FROM events WHERE session_id='test-session-002'"
            ).fetchone()
            conn.close()

            self.assertIsNotNone(row, "Expected a row in events")
            stored = row[0]
            self.assertNotIn("sk-ant-api03", stored,
                             "Secret key should be redacted from tool_input_json")
            self.assertIn("[REDACTED]", stored, "Expected [REDACTED] placeholder")


class TestLogEventExitsZeroOnMalformedStdin(unittest.TestCase):
    """log-event.py must exit 0 even on garbage stdin."""

    def test_log_event_exits_zero_on_malformed_stdin(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = _run_log_event(
                "this is not JSON at all!!! {{{",
                hook_label="postToolUse",
                env={"CLAUDE_PROJECT_DIR": tmp},
            )
            self.assertEqual(result.returncode, 0,
                             f"Expected exit 0 on garbage stdin, got {result.returncode}")
            self.assertIn("malformed", result.stderr.lower(),
                          f"Expected a warning in stderr. Got: {result.stderr!r}")


class TestLogEventFallsBackToJsonlOnDbLock(unittest.TestCase):
    """When the DB is locked, log-event.py must fall back to events.jsonl."""

    def test_log_event_falls_back_to_jsonl_on_db_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_dir = tmp_path / ".claude" / "observability"
            db_dir.mkdir(parents=True)
            db_path = db_dir / "events.db"

            # Create and hold an exclusive lock on the DB using a separate process
            # so SQLite thread-safety constraints don't interfere.
            lock_script = (
                "import sqlite3, time, sys\n"
                f"conn = sqlite3.connect({str(db_path)!r})\n"
                "conn.execute('BEGIN EXCLUSIVE')\n"
                "sys.stdout.write('locked\\n'); sys.stdout.flush()\n"
                "time.sleep(1.0)\n"
                "conn.rollback(); conn.close()\n"
            )
            import subprocess as _sp
            lock_proc = _sp.Popen(
                [sys.executable, "-c", lock_script],
                stdout=_sp.PIPE, stderr=_sp.PIPE,
            )
            try:
                # Wait until the lock process signals it holds the lock
                lock_proc.stdout.readline()  # blocks until "locked\n" is printed

                payload = {
                    "session_id": "test-session-003",
                    "hook_event_name": "PostToolUse",
                    "tool_name": "Write",
                    "tool_input": {"file_path": "/tmp/x.py", "content": "x"},
                    "cwd": tmp,
                }

                result = _run_log_event(
                    payload,
                    hook_label="postToolUse",
                    env={"CLAUDE_PROJECT_DIR": tmp},
                )

                # Must exit 0 regardless
                self.assertEqual(result.returncode, 0,
                                 f"Expected exit 0 on DB lock. stderr: {result.stderr}")

                # Fallback JSONL must have a line
                jsonl_path = db_dir / "events.jsonl"
                self.assertTrue(jsonl_path.exists(),
                                f"events.jsonl fallback not created. stderr: {result.stderr}")
                lines = jsonl_path.read_text().strip().splitlines()
                self.assertGreater(len(lines), 0, "events.jsonl should have at least one line")
                row = json.loads(lines[-1])
                self.assertEqual(row.get("session_id"), "test-session-003")

                lock_proc.wait(timeout=3.0)
            finally:
                if lock_proc.stdout:
                    lock_proc.stdout.close()
                if lock_proc.stderr:
                    lock_proc.stderr.close()
                lock_proc.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)

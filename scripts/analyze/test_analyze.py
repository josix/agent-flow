#!/usr/bin/env python3
"""
Fixture-based smoke tests for analyze.py

Run with: python3 scripts/analyze/test_analyze.py

Tests:
  1. Loader idempotency (INSERT OR REPLACE key guarantee)
  2. Tool-use row extraction
  3. Thinking text extraction
  4. Subagent meta loading
  5. Report rendering (no crash, key sections present)
"""

import json
import pathlib
import sys
import tempfile
import unittest

# Make analyze importable from this script's directory
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import analyze


# ---------------------------------------------------------------------------
# Synthetic JSONL fixtures
# ---------------------------------------------------------------------------

PARENT_EVENTS = [
    {
        "uuid": "aaaa-0001",
        "parentUuid": None,
        "isSidechain": False,
        "sessionId": "sess-test-001",
        "timestamp": "2026-01-01T10:00:00.000Z",
        "gitBranch": "main",
        "cwd": "/tmp/project",
        "type": "user",
        "message": {
            "role": "user",
            "content": [{"type": "text", "text": "Hello"}],
        },
    },
    {
        "uuid": "aaaa-0002",
        "parentUuid": "aaaa-0001",
        "isSidechain": False,
        "sessionId": "sess-test-001",
        "timestamp": "2026-01-01T10:00:05.000Z",
        "gitBranch": "main",
        "cwd": "/tmp/project",
        "type": "assistant",
        "message": {
            "role": "assistant",
            "model": "claude-sonnet-4-6",
            "content": [
                {"type": "thinking", "thinking": "I should use the Read tool."},
                {
                    "type": "tool_use",
                    "id": "tu-read-001",
                    "name": "Read",
                    "input": {"file_path": "/tmp/project/README.md"},
                },
            ],
            "usage": {
                "input_tokens": 100,
                "output_tokens": 50,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 200,
            },
        },
    },
    {
        "uuid": "aaaa-0003",
        "parentUuid": "aaaa-0002",
        "isSidechain": False,
        "sessionId": "sess-test-001",
        "timestamp": "2026-01-01T10:00:06.000Z",
        "gitBranch": "main",
        "cwd": "/tmp/project",
        "type": "user",
        "message": {
            "role": "user",
            "content": [
                {
                    "type": "tool_result",
                    "tool_use_id": "tu-read-001",
                    "content": "# README\nThis is a test project.",
                }
            ],
        },
    },
]

SUBAGENT_META = {"agentType": "agent-flow:Loid", "description": "Test executor agent"}

SUBAGENT_EVENTS = [
    {
        "uuid": "bbbb-0001",
        "parentUuid": None,
        "isSidechain": True,
        "agentId": "deadbeef123",
        "sessionId": "sess-test-001",
        "timestamp": "2026-01-01T10:01:00.000Z",
        "type": "user",
        "message": {
            "role": "user",
            "content": [{"type": "text", "text": "Implement the feature."}],
        },
    },
    {
        "uuid": "bbbb-0002",
        "parentUuid": "bbbb-0001",
        "isSidechain": True,
        "agentId": "deadbeef123",
        "sessionId": "sess-test-001",
        "timestamp": "2026-01-01T10:01:10.000Z",
        "type": "assistant",
        "message": {
            "role": "assistant",
            "model": "claude-sonnet-4-6",
            "content": [
                {
                    "type": "tool_use",
                    "id": "tu-write-001",
                    "name": "Write",
                    "input": {"file_path": "/tmp/project/out.py", "content": "print('hi')"},
                }
            ],
            "usage": {
                "input_tokens": 80,
                "output_tokens": 30,
                "cache_read_input_tokens": 150,
                "cache_creation_input_tokens": 0,
            },
        },
    },
]


def _write_jsonl(path: pathlib.Path, events: list) -> None:
    path.write_text("\n".join(json.dumps(e) for e in events) + "\n")


def _make_transcripts_dir(tmp: pathlib.Path, session_id: str) -> pathlib.Path:
    tdir = tmp / "transcripts"
    tdir.mkdir()

    # Parent JSONL
    _write_jsonl(tdir / f"{session_id}.jsonl", PARENT_EVENTS)

    # Subagent
    sub_dir = tdir / session_id / "subagents"
    sub_dir.mkdir(parents=True)
    _write_jsonl(sub_dir / "agent-deadbeef123.jsonl", SUBAGENT_EVENTS)
    (sub_dir / "agent-deadbeef123.meta.json").write_text(json.dumps(SUBAGENT_META))

    return tdir


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestLoader(unittest.TestCase):

    def setUp(self):
        self.tmpdir = pathlib.Path(tempfile.mkdtemp())
        self.db_path = self.tmpdir / "events.db"
        self.conn = analyze.open_db(self.db_path)
        self.session_id = "sess-test-001"
        self.tdir = _make_transcripts_dir(self.tmpdir, self.session_id)

    def tearDown(self):
        self.conn.close()

    def test_load_creates_events(self):
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        count = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        self.assertGreater(count, 0, "Expected at least one event after load")

    def test_load_idempotent(self):
        """Loading the same session twice should not duplicate events."""
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        count1 = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        count2 = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        self.assertEqual(count1, count2, "Idempotency violated: event count changed on second load")

    def test_tool_use_extracted(self):
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        rows = self.conn.execute(
            "SELECT tool_name FROM events WHERE tool_name IS NOT NULL"
        ).fetchall()
        tool_names = {r[0] for r in rows}
        self.assertIn("Read", tool_names, "Expected 'Read' tool_use row")
        self.assertIn("Write", tool_names, "Expected 'Write' tool_use row from subagent")

    def test_thinking_extracted(self):
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        row = self.conn.execute(
            "SELECT thinking_text FROM events WHERE thinking_text IS NOT NULL LIMIT 1"
        ).fetchone()
        self.assertIsNotNone(row, "Expected at least one event with thinking_text")
        self.assertIn("Read tool", row[0])

    def test_subagent_row_created(self):
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        row = self.conn.execute(
            "SELECT agent_type, description FROM subagents WHERE session_id=?",
            (self.session_id,)
        ).fetchone()
        self.assertIsNotNone(row, "Expected a subagents row")
        self.assertEqual(row[0], "agent-flow:Loid")
        self.assertIn("executor", row[1].lower())

    def test_session_row_created(self):
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        row = self.conn.execute(
            "SELECT session_id, git_branch FROM sessions WHERE session_id=?",
            (self.session_id,)
        ).fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row[0], self.session_id)
        self.assertEqual(row[1], "main")

    def test_redact_flag(self):
        """With --redact, credential-like strings should be masked."""
        secret_event = {
            "uuid": "cccc-0001",
            "parentUuid": None,
            "isSidechain": False,
            "sessionId": self.session_id,
            "timestamp": "2026-01-01T11:00:00.000Z",
            "type": "assistant",
            "message": {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu-secret",
                        "name": "Bash",
                        "input": {"command": "AWS_KEY=AKIAIOSFODNN7EXAMPLE12 echo hi"},
                    }
                ],
            },
        }
        secret_jsonl = self.tdir / f"{self.session_id}_secret.jsonl"
        _write_jsonl(secret_jsonl, [secret_event])

        rows = analyze.parse_event_row(secret_event, self.session_id, None, None, do_redact=True)
        tool_input = rows[0].get("tool_input_json", "")
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE12", tool_input)
        self.assertIn("[REDACTED]", tool_input)


class TestReport(unittest.TestCase):
    """Test that report rendering completes without errors and has expected sections."""

    def test_report_renders(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)
            analyze.apply_views(conn)

            # Capture report output
            import io
            from contextlib import redirect_stdout
            buf = io.StringIO()

            # Must create observability dir so report can write report.md
            obs_dir = tmp_path / ".claude" / "observability"
            obs_dir.mkdir(parents=True)

            orig_cwd = pathlib.Path.cwd()
            try:
                import os
                os.chdir(tmp_path)

                class _Args:
                    db = str(db_path)

                with redirect_stdout(buf):
                    analyze.cmd_report(_Args(), conn)

            finally:
                os.chdir(orig_cwd)
                conn.close()

            output = buf.getvalue()
            self.assertIn("# agent-flow Observability Report", output)
            self.assertIn("## Session Overview", output)
            self.assertIn("## Improvement Opportunities", output)
            self.assertIn("## Tool Usage by Agent", output)


class TestModelMismatch(unittest.TestCase):
    """Tests for the model alias mismatch heuristic."""

    def _check_mismatch(self, declared: str, actual: str) -> bool:
        """Return True if the heuristic would flag a mismatch."""
        alias = declared.lower()
        prefix = analyze.MODEL_ALIAS_PREFIX.get(alias)
        if prefix is not None:
            return not actual.startswith(prefix)
        return actual != declared

    def test_sonnet_alias_matches_full_id(self):
        """'sonnet' alias should NOT flag mismatch for claude-sonnet-4-6."""
        self.assertFalse(self._check_mismatch("sonnet", "claude-sonnet-4-6"))

    def test_opus_alias_mismatches_sonnet_id(self):
        """'opus' alias SHOULD flag mismatch when actual is claude-sonnet-4-6."""
        self.assertTrue(self._check_mismatch("opus", "claude-sonnet-4-6"))

    def test_haiku_alias_matches_full_id(self):
        """'haiku' alias should NOT flag mismatch for claude-haiku-4-5-20251001."""
        self.assertFalse(self._check_mismatch("haiku", "claude-haiku-4-5-20251001"))

    def test_unknown_alias_uses_exact_comparison(self):
        """Unknown alias falls back to exact string comparison — no false positive."""
        # 'flash' is not in the table; exact match should not flag
        self.assertFalse(self._check_mismatch("claude-opus-4-5", "claude-opus-4-5"))
        # exact mismatch is still flagged
        self.assertTrue(self._check_mismatch("claude-opus-4-5", "claude-sonnet-4-6"))


class TestIdempotentRealGrowth(unittest.TestCase):
    """The true idempotency invariant: re-loading the same events produces same rows;
    new events appended to the file are added without touching existing rows."""

    def setUp(self):
        self.tmpdir = pathlib.Path(tempfile.mkdtemp())
        self.db_path = self.tmpdir / "events.db"
        self.conn = analyze.open_db(self.db_path)
        self.session_id = "sess-grow-001"
        self.tdir = self.tmpdir / "transcripts"
        self.tdir.mkdir()
        self.jsonl_path = self.tdir / f"{self.session_id}.jsonl"

    def tearDown(self):
        self.conn.close()

    def test_load_idempotent_real_growth(self):
        """Write some events, load, write more events (simulating active session), load again.
        Asserts:
          (a) events from first write are unchanged (same uuids map to same rows)
          (b) only the new events were added
        """
        first_batch = [
            {
                "uuid": "grow-0001",
                "parentUuid": None,
                "isSidechain": False,
                "timestamp": "2026-01-01T10:00:00.000Z",
                "message": {"role": "user", "content": [{"type": "text", "text": "First"}]},
            },
            {
                "uuid": "grow-0002",
                "parentUuid": "grow-0001",
                "isSidechain": False,
                "timestamp": "2026-01-01T10:00:01.000Z",
                "message": {"role": "assistant", "model": "claude-sonnet-4-6",
                            "content": [{"type": "text", "text": "Reply"}],
                            "usage": {"input_tokens": 10, "output_tokens": 5}},
            },
        ]
        # Write first batch and load
        _write_jsonl(self.jsonl_path, first_batch)
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        count_after_first = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]

        # Verify first-batch rows are present
        row = self.conn.execute(
            "SELECT model FROM events WHERE event_id=?", ("grow-0002",)
        ).fetchone()
        self.assertIsNotNone(row, "grow-0002 should be in DB after first load")
        self.assertEqual(row[0], "claude-sonnet-4-6")

        # Append new events (simulating active session growth)
        second_batch = [
            {
                "uuid": "grow-0003",
                "parentUuid": "grow-0002",
                "isSidechain": False,
                "timestamp": "2026-01-01T10:01:00.000Z",
                "message": {"role": "user", "content": [{"type": "text", "text": "More"}]},
            },
        ]
        # Append second batch to the same file
        with open(self.jsonl_path, "a", encoding="utf-8") as fh:
            for e in second_batch:
                fh.write(json.dumps(e) + "\n")

        # Reload — simulates running analyze again while session is still active
        analyze.load_session(self.conn, self.session_id, self.tdir, do_redact=False)
        count_after_second = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]

        # (a) Original rows must be unchanged
        row_again = self.conn.execute(
            "SELECT model FROM events WHERE event_id=?", ("grow-0002",)
        ).fetchone()
        self.assertIsNotNone(row_again, "grow-0002 must still be present after second load")
        self.assertEqual(row_again[0], "claude-sonnet-4-6", "Row data must be unchanged")

        # (b) Only the new event was added
        new_row = self.conn.execute(
            "SELECT event_id FROM events WHERE event_id=?", ("grow-0003",)
        ).fetchone()
        self.assertIsNotNone(new_row, "grow-0003 must be added after second load")
        self.assertEqual(count_after_second, count_after_first + 1,
                         "Exactly one new event should have been added")


class TestSessionValidation(unittest.TestCase):
    """Tests for --session UUID input validation."""

    def test_session_id_validation_rejects_path_traversal(self):
        """'--session ../../etc/passwd' should cause sys.exit(2) before file I/O."""
        import subprocess
        result = subprocess.run(
            [sys.executable,
             str(pathlib.Path(__file__).parent / "analyze.py"),
             "load", "--session", "../../etc/passwd"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2,
                         f"Expected exit code 2, got {result.returncode}. stderr: {result.stderr}")

    def test_session_id_validation_accepts_valid_uuid(self):
        """A valid UUID format does not cause early exit 2 (may fail for other reasons)."""
        import subprocess
        valid_uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        result = subprocess.run(
            [sys.executable,
             str(pathlib.Path(__file__).parent / "analyze.py"),
             "load", "--session", valid_uuid],
            capture_output=True, text=True,
        )
        # Should fail with exit 1 (transcripts dir not found), NOT exit 2
        self.assertNotEqual(result.returncode, 2,
                            "Valid UUID should not be rejected by UUID validator")


class TestRedactModule(unittest.TestCase):
    """Test that redact.py is importable and works correctly."""

    def test_redact_module_importable(self):
        from redact import redact as _redact
        # Known AWS key pattern should be masked
        result = _redact("AKIAIOSFODNN7EXAMPLE12")
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE12", result)
        self.assertIn("[REDACTED]", result)

    def test_redact_anthropic_key(self):
        from redact import redact as _redact
        secret = "sk-ant-api03-XXXXXXXXXXXXXXXXXXXX1234567890abcdef"
        result = _redact(secret)
        self.assertNotIn("sk-ant-api03", result)
        self.assertIn("[REDACTED]", result)

    def test_redact_none_passthrough(self):
        from redact import redact as _redact
        self.assertIsNone(_redact(None))


class TestRetention(unittest.TestCase):
    """Tests for the retention subcommand."""

    def setUp(self):
        self.tmpdir = pathlib.Path(tempfile.mkdtemp())
        self.db_path = self.tmpdir / "events.db"
        self.conn = analyze.open_db(self.db_path)

    def tearDown(self):
        self.conn.close()

    def _insert_event(self, event_id: str, ts: str) -> None:
        self.conn.execute("""
            INSERT OR REPLACE INTO events
              (event_id, session_id, ts, role)
            VALUES (?, 'test-sess', ?, 'user')
        """, (event_id, ts))
        self.conn.commit()

    def test_retention_deletes_old_events(self):
        """retention --days 7 should delete events older than 7 days and keep recent ones."""
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc)
        old_ts = (now - datetime.timedelta(days=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
        new_ts = (now - datetime.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")

        self._insert_event("old-event-001", old_ts)
        self._insert_event("new-event-001", new_ts)

        count_before = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        self.assertEqual(count_before, 2)

        class _Args:
            days = 7
            all = False

        analyze.cmd_retention(_Args(), self.conn)

        remaining = self.conn.execute("SELECT event_id FROM events").fetchall()
        remaining_ids = {r[0] for r in remaining}
        self.assertNotIn("old-event-001", remaining_ids, "Old event should be deleted")
        self.assertIn("new-event-001", remaining_ids, "Recent event should be kept")

    def test_retention_all_wipes(self):
        """retention --all should clear events and subagents tables."""
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc)
        ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")

        self._insert_event("evt-001", ts)
        self._insert_event("evt-002", ts)

        self.conn.execute("""
            INSERT OR REPLACE INTO subagents (agent_id, session_id)
            VALUES ('agent-001', 'test-sess')
        """)
        self.conn.commit()

        count_events = self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        count_sub = self.conn.execute("SELECT COUNT(*) FROM subagents").fetchone()[0]
        self.assertEqual(count_events, 2)
        self.assertEqual(count_sub, 1)

        class _Args:
            days = None
            all = True

        analyze.cmd_retention(_Args(), self.conn)

        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM events").fetchone()[0], 0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM subagents").fetchone()[0], 0)


class TestMalformedJsonl(unittest.TestCase):
    """Loader must skip garbage lines without crashing."""

    def test_malformed_jsonl_line_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)
            tdir = tmp_path / "transcripts"
            tdir.mkdir()
            session_id = "sess-bad-001"
            jsonl_path = tdir / f"{session_id}.jsonl"

            # Mix a garbage line with a valid event
            valid_event = {
                "uuid": "bad-0001",
                "parentUuid": None,
                "isSidechain": False,
                "timestamp": "2026-01-01T12:00:00.000Z",
                "message": {"role": "user", "content": [{"type": "text", "text": "Hi"}]},
            }
            jsonl_path.write_text(
                "this is not json at all\n"
                + json.dumps(valid_event) + "\n"
                + "{broken: json}\n"
            )

            # Should not raise
            analyze.load_session(conn, session_id, tdir, do_redact=False)
            count = conn.execute("SELECT COUNT(*) FROM events WHERE session_id=?",
                                 (session_id,)).fetchone()[0]
            self.assertEqual(count, 1, "Only the valid event should be loaded; garbage lines skipped")
            conn.close()


# ---------------------------------------------------------------------------
# M4 Tests
# ---------------------------------------------------------------------------

class TestReportSessionFilter(unittest.TestCase):
    """M4a: report --session <id> writes a per-session file."""

    def test_report_session_filter(self):
        import io
        import os
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)

            session_id = "sess-test-001"
            tdir = _make_transcripts_dir(tmp_path, session_id)
            analyze.load_session(conn, session_id, tdir, do_redact=False)
            analyze.apply_views(conn)

            obs_dir = tmp_path / ".claude" / "observability"
            obs_dir.mkdir(parents=True)

            orig_cwd = pathlib.Path.cwd()
            try:
                os.chdir(tmp_path)

                class _Args:
                    db = str(db_path)
                    session = session_id

                buf = io.StringIO()
                with redirect_stdout(buf):
                    analyze.cmd_report(_Args(), conn)

            finally:
                os.chdir(orig_cwd)
                conn.close()

            # Per-session file must exist
            per_session_file = obs_dir / f"{session_id}.md"
            self.assertTrue(per_session_file.exists(), "Per-session .md file was not written")

            content = per_session_file.read_text()
            self.assertIn(session_id[:8], content, "Session ID should appear in per-session report")

            # Verify ANSI codes are stripped from the file
            self.assertNotIn("\033[", content, "File must not contain ANSI escape codes")


class TestAnsiColorRespectsNoColor(unittest.TestCase):
    """M4b: with NO_COLOR=1, output must not contain ANSI escape codes."""

    def test_ansi_color_respects_no_color_env(self):
        import io
        import os
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)
            analyze.apply_views(conn)

            obs_dir = tmp_path / ".claude" / "observability"
            obs_dir.mkdir(parents=True)

            orig_cwd = pathlib.Path.cwd()
            orig_no_color = os.environ.get("NO_COLOR")
            try:
                os.chdir(tmp_path)
                os.environ["NO_COLOR"] = "1"

                # Reload _ansi module to pick up env
                import importlib
                import _ansi
                importlib.reload(_ansi)

                class _Args:
                    db = str(db_path)
                    session = None

                buf = io.StringIO()
                with redirect_stdout(buf):
                    analyze.cmd_report(_Args(), conn)

            finally:
                os.chdir(orig_cwd)
                if orig_no_color is None:
                    os.environ.pop("NO_COLOR", None)
                else:
                    os.environ["NO_COLOR"] = orig_no_color
                import importlib
                import _ansi
                importlib.reload(_ansi)
                conn.close()

            output = buf.getvalue()
            self.assertNotIn("\033[", output, "ANSI codes must not appear when NO_COLOR is set")


# ---------------------------------------------------------------------------
# M5 Tests
# ---------------------------------------------------------------------------

class TestLabelsTableCreated(unittest.TestCase):
    """M5a: schema must create the labels table."""

    def test_labels_table_created(self):
        with tempfile.TemporaryDirectory() as tmp:
            db_path = pathlib.Path(tmp) / "events.db"
            conn = analyze.open_db(db_path)
            tables = {r[0] for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()}
            conn.close()
            self.assertIn("labels", tables, "labels table should be created by schema")


class TestLabelExportComputesPrecisionRecall(unittest.TestCase):
    """M5c: label export computes correct precision and recall_proxy."""

    def test_label_export_computes_precision_recall(self):
        import io
        import os
        import csv as _csv
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)

            session_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            agent_type = "agent-flow:Loid"
            ts = "2026-01-01T10:00:00Z"

            # Insert synthetic labels: 3 correct, 1 missed, 1 extra, 1 wrong
            labels = [
                ("label-001", session_id, "agent-001", agent_type, "correct", None, ts),
                ("label-002", session_id, "agent-002", agent_type, "correct", None, ts),
                ("label-003", session_id, "agent-003", agent_type, "correct", None, ts),
                ("label-004", session_id, "agent-004", agent_type, "missed", None, ts),
                ("label-005", session_id, "agent-005", agent_type, "extra", None, ts),
                ("label-006", session_id, "agent-006", agent_type, "wrong", None, ts),
            ]
            conn.executemany(
                "INSERT INTO labels (label_id, session_id, agent_id, agent_type, verdict, note, ts) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                labels
            )
            conn.commit()

            obs_dir = tmp_path / ".claude" / "observability"
            obs_dir.mkdir(parents=True)

            orig_cwd = pathlib.Path.cwd()
            try:
                os.chdir(tmp_path)

                class _Args:
                    session_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                    all = False

                buf = io.StringIO()
                with redirect_stdout(buf):
                    analyze.cmd_label_export(_Args(), conn)

            finally:
                os.chdir(orig_cwd)
                conn.close()

            output = buf.getvalue()
            reader = _csv.DictReader(io.StringIO(output))
            rows = list(reader)
            self.assertEqual(len(rows), 1, "Expected one CSV data row")
            row = rows[0]
            # precision = correct / (correct + extra + wrong) = 3 / (3+1+1) = 0.6
            self.assertAlmostEqual(float(row["precision"]), 0.6, places=3)
            # recall_proxy = correct / (correct + missed) = 3 / (3+1) = 0.75
            self.assertAlmostEqual(float(row["recall_proxy"]), 0.75, places=3)


# ---------------------------------------------------------------------------
# M6 Tests
# ---------------------------------------------------------------------------

class TestJsonlExporterWritesLinePerEvent(unittest.TestCase):
    """M6b: JSONL exporter writes one line per event."""

    def test_jsonl_exporter_writes_line_per_event(self):
        import sys as _sys
        sys.path.insert(0, str(pathlib.Path(__file__).parent))
        from exporters.jsonl import JsonlExporter

        with tempfile.TemporaryDirectory() as tmp:
            out_path = pathlib.Path(tmp) / "export.jsonl"
            exporter = JsonlExporter({"path": str(out_path)})

            events = [
                {"event_id": "e1", "ts": "2026-01-01T10:00:00Z", "tool_name": "Read"},
                {"event_id": "e2", "ts": "2026-01-01T10:00:01Z", "tool_name": "Write"},
                {"event_id": "e3", "ts": "2026-01-01T10:00:02Z", "tool_name": "Bash"},
            ]
            count = exporter.export(iter(events))

            self.assertEqual(count, 3, "Should export 3 events")
            self.assertTrue(out_path.exists(), "JSONL file should be created")
            lines = [l for l in out_path.read_text().splitlines() if l.strip()]
            self.assertEqual(len(lines), 3, "Should have 3 lines in JSONL file")


class TestMlflowExporterRaisesWhenNotInstalled(unittest.TestCase):
    """M6b: mlflow exporter raises ExporterUnavailable when mlflow is not installed."""

    def test_mlflow_exporter_raises_when_not_installed(self):
        import sys as _sys
        sys.path.insert(0, str(pathlib.Path(__file__).parent))
        from exporters.base import ExporterUnavailable
        from exporters.mlflow import MlflowExporter

        # Monkeypatch: force ImportError by temporarily removing mlflow from sys.modules
        original = _sys.modules.get("mlflow", None)
        _sys.modules["mlflow"] = None  # type: ignore[assignment]
        try:
            exporter = MlflowExporter({})
            with self.assertRaises(ExporterUnavailable):
                exporter.export(iter([{"event_id": "e1", "ts": "2026-01-01T10:00:00Z"}]))
        finally:
            if original is None:
                _sys.modules.pop("mlflow", None)
            else:
                _sys.modules["mlflow"] = original


class TestExportCommandSkipsMissingConfig(unittest.TestCase):
    """M6c: export command prints 'no exporters configured' when observability.json is absent."""

    def test_export_command_skips_missing_config(self):
        import io
        import os
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            db_path = tmp_path / "events.db"
            conn = analyze.open_db(db_path)

            orig_cwd = pathlib.Path.cwd()
            try:
                os.chdir(tmp_path)
                # No .claude/observability.json present

                class _Args:
                    exporter = None
                    session = None

                buf = io.StringIO()
                with redirect_stdout(buf):
                    analyze.cmd_export(_Args(), conn)

            finally:
                os.chdir(orig_cwd)
                conn.close()

            output = buf.getvalue()
            self.assertIn("no exporters configured", output)


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""
log-event.py — live hook sink for agent-flow observability.

Reads one JSON payload from stdin per invocation, inserts one row into
.claude/observability/events.db, exits 0 always.

Usage (from hook command):
  log-event.py <hook_event_label>
  Where hook_event_label is one of: preToolUse postToolUse subagentStop sessionEnd

This script is best-effort: any failure is printed to stderr and exit 0.
"""

# NOTE: Keep imports minimal — every import adds ~1-3 ms to startup latency.
# No third-party deps; stdlib only.
import json
import os
import re
import sqlite3
import sys

# ---------------------------------------------------------------------------
# Redaction — inline to keep stdlib-only (no imports from sibling package)
# ---------------------------------------------------------------------------

_REDACT_PATTERNS = [
    r"AKIA[0-9A-Z]{16}",
    r"sk-ant-[A-Za-z0-9\-_]{20,}",
    r"sk-[A-Za-z0-9]{20,}",
    r"ghp_[A-Za-z0-9]{36}",
    r"github_pat_[A-Za-z0-9_]{40,}",
    r"xoxb-[A-Za-z0-9\-]{10,}",
    r"xoxp-[A-Za-z0-9\-]{10,}",
    r"-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----",
]
_REDACT_RE = re.compile("|".join(_REDACT_PATTERNS))


def _redact(s):
    if s is None:
        return None
    return _REDACT_RE.sub("[REDACTED]", s)


# ---------------------------------------------------------------------------
# Schema (subset of schema.sql — only what log-event writes)
# ---------------------------------------------------------------------------

_SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

CREATE TABLE IF NOT EXISTS sessions (
  session_id  TEXT PRIMARY KEY,
  started_at  TEXT,
  ended_at    TEXT,
  git_branch  TEXT,
  cwd         TEXT,
  parent_jsonl_path TEXT,
  event_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS events (
  event_id          TEXT PRIMARY KEY,
  session_id        TEXT NOT NULL,
  parent_uuid       TEXT,
  agent_id          TEXT,
  agent_type        TEXT,
  role              TEXT,
  tool_use_id       TEXT,
  tool_name         TEXT,
  tool_input_json   TEXT,
  tool_result_json  TEXT,
  decision          TEXT,
  thinking_text     TEXT,
  input_tokens      INTEGER,
  output_tokens     INTEGER,
  cache_read_tokens INTEGER,
  cache_creation_tokens INTEGER,
  model             TEXT,
  git_branch        TEXT,
  cwd               TEXT,
  is_sidechain      INTEGER,
  ts                TEXT NOT NULL,
  hook_event        TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_session   ON events(session_id, ts);
CREATE INDEX IF NOT EXISTS idx_events_tool      ON events(tool_name);
CREATE INDEX IF NOT EXISTS idx_events_hook      ON events(hook_event);
"""

_INSERT_SQL = """
    INSERT OR REPLACE INTO events
      (event_id, session_id, hook_event, tool_name, tool_input_json,
       tool_result_json, git_branch, cwd, ts, tool_use_id, agent_id,
       is_sidechain, role, parent_uuid, agent_type, decision,
       thinking_text, input_tokens, output_tokens,
       cache_read_tokens, cache_creation_tokens, model)
    VALUES
      (:event_id, :session_id, :hook_event, :tool_name, :tool_input_json,
       :tool_result_json, :git_branch, :cwd, :ts, :tool_use_id, :agent_id,
       NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL,
       NULL, NULL, NULL)
"""


def _resolve_db(cwd):
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or cwd or os.getcwd()
    return os.path.join(project_dir, ".claude", "observability", "events.db")


def _open_db(db_path):
    db_dir = os.path.dirname(db_path)
    os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=0.5)
    conn.execute("PRAGMA busy_timeout = 200;")
    conn.executescript(_SCHEMA)
    # Migration: add hook_event column if not present (M1 DBs lack it)
    existing = {r[1] for r in conn.execute("PRAGMA table_info(events)")}
    if "hook_event" not in existing:
        conn.execute("ALTER TABLE events ADD COLUMN hook_event TEXT")
    conn.commit()
    return conn


def _git_branch(cwd):
    try:
        git_head = os.path.join(cwd, ".git", "HEAD")
        if os.path.exists(git_head):
            with open(git_head) as f:
                text = f.read().strip()
            if text.startswith("ref: refs/heads/"):
                return text[len("ref: refs/heads/"):]
    except Exception:
        pass
    return None


def _fallback_jsonl(db_path, row):
    jsonl_path = os.path.join(os.path.dirname(db_path), "events.jsonl")
    try:
        with open(jsonl_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row) + "\n")
    except Exception as e:
        print("log-event fallback-jsonl error: " + str(e), file=sys.stderr)


def _now_iso():
    # Avoid importing datetime — use time module which is already loaded by sqlite3
    import time
    t = time.gmtime()
    return "%04d-%02d-%02dT%02d:%02d:%02dZ" % (
        t.tm_year, t.tm_mon, t.tm_mday,
        t.tm_hour, t.tm_min, t.tm_sec,
    )


def _uuid4():
    # Avoid uuid module import — use os.urandom
    b = os.urandom(16)
    b = bytearray(b)
    b[6] = (b[6] & 0x0f) | 0x40
    b[8] = (b[8] & 0x3f) | 0x80
    h = b.hex()
    return "%s-%s-%s-%s-%s" % (h[0:8], h[8:12], h[12:16], h[16:20], h[20:32])


def main():
    try:
        hook_label = sys.argv[1] if len(sys.argv) > 1 else "unknown"

        raw_stdin = sys.stdin.read()
        try:
            payload = json.loads(raw_stdin)
        except ValueError as e:
            print("log-event warning: malformed stdin JSON: " + str(e), file=sys.stderr)
            sys.exit(0)

        session_id = payload.get("session_id") or payload.get("sessionId") or "unknown"
        hook_event_name = payload.get("hook_event_name") or hook_label
        cwd = payload.get("cwd") or os.getcwd()
        tool_name = payload.get("tool_name") or payload.get("toolName")
        tool_input = payload.get("tool_input") or payload.get("toolInput")
        tool_response = payload.get("tool_response") or payload.get("toolResponse")

        tool_input_json = None
        if tool_input is not None:
            raw = tool_input if isinstance(tool_input, str) else json.dumps(tool_input)
            tool_input_json = _redact(raw)

        tool_result_json = None
        if tool_response is not None:
            raw = tool_response if isinstance(tool_response, str) else json.dumps(tool_response)
            tool_result_json = _redact(raw)

        agent_id = payload.get("agent_id") or payload.get("agentId")
        tool_use_id = payload.get("tool_use_id") or payload.get("toolUseId")
        if hook_label == "subagentStop" and not tool_use_id:
            tool_use_id = agent_id

        ts = _now_iso()
        event_id = _uuid4()
        git_branch = _git_branch(cwd)

        row = {
            "event_id": event_id,
            "session_id": session_id,
            "hook_event": hook_event_name,
            "tool_name": tool_name,
            "tool_input_json": tool_input_json,
            "tool_result_json": tool_result_json,
            "git_branch": git_branch,
            "cwd": cwd,
            "ts": ts,
            "tool_use_id": tool_use_id,
            "agent_id": agent_id,
        }

        db_path = _resolve_db(cwd)

        try:
            conn = _open_db(db_path)
            try:
                conn.execute(_INSERT_SQL, row)
                conn.commit()

                if hook_label == "sessionEnd":
                    conn.execute(
                        "INSERT OR IGNORE INTO sessions (session_id, started_at, ended_at, cwd) VALUES (?, ?, ?, ?)",
                        (session_id, ts, ts, cwd),
                    )
                    conn.execute(
                        "UPDATE sessions SET ended_at=? WHERE session_id=?",
                        (ts, session_id),
                    )
                    conn.commit()

            except sqlite3.OperationalError as e:
                print("log-event warning: DB locked (" + str(e) + "), falling back to JSONL",
                      file=sys.stderr)
                _fallback_jsonl(db_path, row)
            finally:
                conn.close()
        except sqlite3.OperationalError as e:
            print("log-event warning: cannot open DB (" + str(e) + "), falling back to JSONL",
                  file=sys.stderr)
            _fallback_jsonl(db_path, row)

    except Exception as e:
        print("log-event error: " + str(e), file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()

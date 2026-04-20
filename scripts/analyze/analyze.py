#!/usr/bin/env python3
"""
agent-flow analyze — offline transcript parser and observability reporter.

Parses Claude Code JSONL transcripts into SQLite, then surfaces subagent
behavior and improvement opportunities.

Usage:
  analyze.py load [--transcripts-dir DIR] [--session ID | --all-sessions] [--redact]
  analyze.py report [--db PATH]
  analyze.py sessions [--db PATH]
  analyze.py sql QUERY [--db PATH]

Flags:
  --db PATH            SQLite database path (default: .claude/observability/events.db)
  --transcripts-dir    Override transcript directory (default: auto-detect from cwd)
  --session ID         Load only one session
  --all-sessions       Load all sessions in transcripts dir
  --redact             Mask credential patterns in tool_input_json / tool_result_json
                       before storing. Patterns: AWS key (AKIA...), OpenAI key (sk-...),
                       GitHub PAT (ghp_...). Off by default (local use).
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sqlite3
import sys
import datetime

import csv
import io
import uuid as _uuid_mod

from redact import redact, REDACT_RE  # noqa: F401 — re-exported for backward compat
from _ansi import red, yellow, green  # noqa: F401

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCHEMA_SQL = pathlib.Path(__file__).with_name("schema.sql")
VIEWS_SQL  = pathlib.Path(__file__).with_name("views.sql")

DEFAULT_DB = pathlib.Path(".claude/observability/events.db")

REPORT_TOP_N = 10

# Session ID validation: UUID-like hex string of length 36
SESSION_ID_RE = re.compile(r"^[0-9a-f\-]{36}$")

# Model alias to canonical prefix mapping
MODEL_ALIAS_PREFIX = {
    "sonnet": "claude-sonnet",
    "opus":   "claude-opus",
    "haiku":  "claude-haiku",
}

# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------

def open_db(db_path: pathlib.Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    # Apply schema
    schema = SCHEMA_SQL.read_text()
    conn.executescript(schema)
    conn.commit()
    return conn


def apply_views(conn: sqlite3.Connection) -> None:
    views = VIEWS_SQL.read_text()
    conn.executescript(views)
    conn.commit()


# ---------------------------------------------------------------------------
# Transcript path detection
# ---------------------------------------------------------------------------

def default_transcripts_dir() -> pathlib.Path:
    """
    Derive transcripts dir the same way Claude Code does:
    ~/.claude/projects/<slug> where slug = cwd with '/' -> '-' and '.' -> '-'.
    The resulting slug retains the leading '-' (e.g. /Users/foo → -Users-foo).
    Falls back to scanning ~/.claude/projects/ for the best match if the
    exact slug does not exist.
    """
    cwd = pathlib.Path.cwd()
    # Claude Code: replace '/' with '-', replace '.' with '-'
    slug = str(cwd).replace("/", "-").replace(".", "-")
    # Slug retains the leading '-' since cwd starts with '/'
    projects = pathlib.Path.home() / ".claude" / "projects"
    exact = projects / slug
    if exact.exists():
        return exact

    # Fallback: find the best-matching directory under ~/.claude/projects/
    if projects.exists():
        best = None
        best_score = 0
        for p in projects.iterdir():
            if not p.is_dir():
                continue
            # Score: length of common suffix between slug and dir name
            a = slug
            b = p.name
            score = 0
            for ca, cb in zip(reversed(a), reversed(b)):
                if ca == cb:
                    score += 1
                else:
                    break
            if score > best_score:
                best_score = score
                best = p
        if best and best_score >= 10:
            return best

    return exact  # Return non-existent path; caller will error


# ---------------------------------------------------------------------------
# JSONL event parsing
# ---------------------------------------------------------------------------

def _extract_thinking(content: list) -> str:
    parts = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "thinking":
            t = block.get("thinking", "")
            if t:
                parts.append(t)
    return "\n".join(parts)


def _extract_tool_uses(content: list) -> list:
    """Return list of (tool_use_id, tool_name, tool_input_json) from content."""
    uses = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_use":
            uses.append((
                block.get("id", ""),
                block.get("name", ""),
                json.dumps(block.get("input", {})),
            ))
    return uses


def _extract_tool_results(content) -> list:
    """Return list of (tool_use_id, result_json) from user message content."""
    results: list[tuple[str, str]] = []
    if not isinstance(content, list):
        return results
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_result":
            tool_use_id = block.get("tool_use_id", "")
            # content may be string or list
            inner = block.get("content", "")
            if isinstance(inner, list):
                texts = []
                for b in inner:
                    if isinstance(b, dict) and b.get("type") == "text":
                        texts.append(b.get("text", ""))
                inner = "\n".join(texts)
            results.append((tool_use_id, json.dumps(inner) if not isinstance(inner, str) else inner))
    return results


def _try_parse_decision(attachment: dict) -> str | None:
    """Best-effort: extract decision from hook attachment."""
    if not attachment:
        return None
    hook_event = attachment.get("hookEvent", "")
    if hook_event not in ("Stop", "PreToolUse", "PostToolUse"):
        return None
    # Try stdout / content fields
    for field in ("stdout", "content"):
        raw = attachment.get(field, "")
        if not raw:
            continue
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict) and "decision" in parsed:
                return parsed["decision"]
        except (json.JSONDecodeError, TypeError):
            # Try regex
            m = re.search(r'"decision"\s*:\s*"([^"]+)"', raw)
            if m:
                return m.group(1)
    return None


def parse_event_row(raw: dict, session_id: str, agent_id: str | None,
                    agent_type: str | None, do_redact: bool) -> list[dict]:
    """
    Parse one JSONL line into 1+ event row dicts.
    Returns a list because one message may contain multiple tool_use blocks.
    """
    uuid      = raw.get("uuid", "")
    parent_uuid = raw.get("parentUuid")
    ts        = raw.get("timestamp", "")
    git_branch = raw.get("gitBranch")
    cwd_val   = raw.get("cwd")
    is_sidechain = 1 if raw.get("isSidechain") else 0

    attachment = raw.get("attachment") or {}
    decision = _try_parse_decision(attachment)

    msg = raw.get("message") or {}
    role  = msg.get("role")
    model = msg.get("model")
    usage = msg.get("usage") or {}
    input_tokens  = usage.get("input_tokens")
    output_tokens = usage.get("output_tokens")
    cache_read    = usage.get("cache_read_input_tokens")
    cache_create  = usage.get("cache_creation_input_tokens")

    content = msg.get("content") or []
    if isinstance(content, str):
        # Plain text content
        content = [{"type": "text", "text": content}]

    thinking_text = _extract_thinking(content)
    tool_uses     = _extract_tool_uses(content)
    tool_results  = _extract_tool_results(content)

    base = dict(
        session_id=session_id,
        parent_uuid=parent_uuid,
        agent_id=agent_id,
        agent_type=agent_type,
        role=role,
        decision=decision,
        thinking_text=thinking_text if thinking_text else None,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        cache_read_tokens=cache_read,
        cache_creation_tokens=cache_create,
        model=model,
        git_branch=git_branch,
        cwd=cwd_val,
        is_sidechain=is_sidechain,
        ts=ts,
        tool_use_id=None,
        tool_name=None,
        tool_input_json=None,
        tool_result_json=None,
    )

    rows = []

    if tool_uses:
        # One row per tool_use; carry thinking only on the first row
        for i, (tuid, tname, tinput) in enumerate(tool_uses):
            if do_redact:
                tinput = redact(tinput)
            row = dict(base)
            row["event_id"]        = f"{uuid}__tu_{i}" if i > 0 else uuid
            row["tool_use_id"]     = tuid
            row["tool_name"]       = tname
            row["tool_input_json"] = tinput
            # Only first row gets thinking + token counts
            if i > 0:
                row["thinking_text"]       = None
                row["input_tokens"]        = None
                row["output_tokens"]       = None
                row["cache_read_tokens"]   = None
                row["cache_creation_tokens"] = None
            rows.append(row)
    elif tool_results:
        # user turn with tool_result blocks
        for i, (tuid, tresult) in enumerate(tool_results):
            if do_redact:
                tresult = redact(tresult)
            row = dict(base)
            row["event_id"]         = f"{uuid}__tr_{i}" if i > 0 else uuid
            row["tool_use_id"]      = tuid
            row["tool_result_json"] = tresult
            if i > 0:
                row["thinking_text"]       = None
                row["input_tokens"]        = None
                row["output_tokens"]       = None
                row["cache_read_tokens"]   = None
                row["cache_creation_tokens"] = None
            rows.append(row)
    else:
        row = dict(base)
        row["event_id"] = uuid
        rows.append(row)

    return rows


# ---------------------------------------------------------------------------
# Session / subagent loading
# ---------------------------------------------------------------------------

def load_counts_by_session(conn: sqlite3.Connection) -> dict[str, int]:
    """Return {session_id: event_count} for all sessions in the DB."""
    rows = conn.execute("SELECT session_id, COUNT(*) FROM events GROUP BY session_id").fetchall()
    return {r[0]: r[1] for r in rows}


def upsert_events(conn: sqlite3.Connection, rows: list[dict]) -> None:
    if not rows:
        return
    conn.executemany("""
        INSERT OR REPLACE INTO events
          (event_id, session_id, parent_uuid, agent_id, agent_type, role,
           tool_use_id, tool_name, tool_input_json, tool_result_json,
           decision, thinking_text, input_tokens, output_tokens,
           cache_read_tokens, cache_creation_tokens, model,
           git_branch, cwd, is_sidechain, ts)
        VALUES
          (:event_id, :session_id, :parent_uuid, :agent_id, :agent_type, :role,
           :tool_use_id, :tool_name, :tool_input_json, :tool_result_json,
           :decision, :thinking_text, :input_tokens, :output_tokens,
           :cache_read_tokens, :cache_creation_tokens, :model,
           :git_branch, :cwd, :is_sidechain, :ts)
    """, rows)


def load_parent_jsonl(conn: sqlite3.Connection, jsonl_path: pathlib.Path,
                      session_id: str, do_redact: bool) -> dict:
    """Load parent-level JSONL. Returns {session_id: {started_at, ended_at, git_branch, cwd}}."""
    meta: dict[str, int | str | None] = {"started_at": None, "ended_at": None, "git_branch": None, "cwd": None, "event_count": 0}
    all_rows = []
    try:
        with open(jsonl_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    raw = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = raw.get("timestamp", "")
                if ts:
                    if meta["started_at"] is None or ts < meta["started_at"]:
                        meta["started_at"] = ts
                    if meta["ended_at"] is None or ts > meta["ended_at"]:
                        meta["ended_at"] = ts
                if raw.get("gitBranch") and not meta["git_branch"]:
                    meta["git_branch"] = raw["gitBranch"]
                if raw.get("cwd") and not meta["cwd"]:
                    meta["cwd"] = raw["cwd"]

                rows = parse_event_row(raw, session_id, None, None, do_redact)
                all_rows.extend(rows)

    except FileNotFoundError:
        return meta

    upsert_events(conn, all_rows)
    meta["event_count"] = len(all_rows)
    return meta


def load_subagent(conn: sqlite3.Connection, jsonl_path: pathlib.Path,
                  session_id: str, agent_id: str, agent_type: str,
                  description: str, do_redact: bool) -> dict:
    """Load a subagent JSONL. Returns timing info."""
    meta = {"spawned_at": None, "stopped_at": None, "model": None}
    all_rows = []
    try:
        with open(jsonl_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    raw = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = raw.get("timestamp", "")
                if ts:
                    if meta["spawned_at"] is None or ts < meta["spawned_at"]:
                        meta["spawned_at"] = ts
                    if meta["stopped_at"] is None or ts > meta["stopped_at"]:
                        meta["stopped_at"] = ts
                msg = raw.get("message") or {}
                if msg.get("model") and not meta["model"]:
                    meta["model"] = msg["model"]

                rows = parse_event_row(raw, session_id, agent_id, agent_type, do_redact)
                all_rows.extend(rows)

    except FileNotFoundError:
        return meta

    upsert_events(conn, all_rows)

    conn.execute("""
        INSERT OR REPLACE INTO subagents
          (agent_id, session_id, agent_type, description, spawned_at, stopped_at, model)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (agent_id, session_id, agent_type, description,
          meta["spawned_at"], meta["stopped_at"], meta["model"]))

    return meta


def load_session(conn: sqlite3.Connection, session_id: str,
                 transcripts_dir: pathlib.Path, do_redact: bool) -> None:
    """Load one session: parent JSONL + all subagent JSONLs."""
    parent_jsonl = transcripts_dir / f"{session_id}.jsonl"
    session_dir  = transcripts_dir / session_id
    subagents_dir = session_dir / "subagents"

    if not parent_jsonl.exists() and not session_dir.exists():
        print(f"  [warn] session {session_id}: no JSONL or directory found, skipping",
              file=sys.stderr)
        return

    print(f"  loading session {session_id} ...", file=sys.stderr)

    # Parent JSONL
    smeta = {"started_at": None, "ended_at": None, "git_branch": None, "cwd": None, "event_count": 0}
    if parent_jsonl.exists():
        smeta.update(load_parent_jsonl(conn, parent_jsonl, session_id, do_redact))

    # Subagents
    if subagents_dir.exists():
        for meta_file in sorted(subagents_dir.glob("agent-*.meta.json")):
            try:
                agent_meta = json.loads(meta_file.read_text())
            except (json.JSONDecodeError, OSError):
                agent_meta = {}
            agent_id   = meta_file.stem.replace(".meta", "").replace("agent-", "")
            agent_type = agent_meta.get("agentType", "")
            description = agent_meta.get("description", "")

            agent_jsonl = subagents_dir / f"agent-{agent_id}.jsonl"
            ameta = load_subagent(conn, agent_jsonl, session_id,
                                  agent_id, agent_type, description, do_redact)
            if smeta["started_at"] is None or (ameta["spawned_at"] and ameta["spawned_at"] < smeta["started_at"]):
                if ameta["spawned_at"]:
                    smeta["started_at"] = min(
                        smeta["started_at"] or ameta["spawned_at"], ameta["spawned_at"]
                    )

    # Upsert session row
    event_count = conn.execute(
        "SELECT COUNT(*) FROM events WHERE session_id=?", (session_id,)
    ).fetchone()[0]

    conn.execute("""
        INSERT OR REPLACE INTO sessions
          (session_id, started_at, ended_at, git_branch, cwd, parent_jsonl_path, event_count)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (session_id, smeta.get("started_at"), smeta.get("ended_at"),
          smeta.get("git_branch"), smeta.get("cwd"),
          str(parent_jsonl) if parent_jsonl.exists() else None,
          event_count))

    conn.commit()


# ---------------------------------------------------------------------------
# Orchestration log parsing
# ---------------------------------------------------------------------------

def _parse_orchestration_log(conn: sqlite3.Connection, session_id: str) -> None:
    """
    Parse .claude/orchestration.local.md for iteration log entries.
    Best-effort: supports two formats:
      New format (update-orchestration-state.sh):
        frontmatter field:  iteration: N
        body heading:       ### Phase: PhaseName
      Old format (legacy):
        ### Phase: planning | Iteration 2
      Agent line (both formats):
        - Agent: Loid | Gate: pass | ...
    """
    log_path = pathlib.Path(".claude/orchestration.local.md")
    if not log_path.exists():
        return

    text = log_path.read_text(errors="replace")
    # Old format: phase and iteration on same line
    old_phase_re = re.compile(r"###\s+(?:Phase[:\s]+)?(\w+).*[Ii]teration\s+(\d+)", re.IGNORECASE)
    # New format: separate frontmatter iteration field and body phase heading
    frontmatter_iter_re = re.compile(r"^iteration:\s*(\d+)", re.IGNORECASE)
    body_phase_re = re.compile(r"^###\s+Phase:\s+(\w+)", re.IGNORECASE)
    agent_re = re.compile(r"-\s+Agent:\s*(\S+)\s*\|\s*Gate[:\s]+(\w+)\s*\|(.*)", re.IGNORECASE)
    ts_now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    rows = []
    current_phase = None
    current_iter = None

    # Regexes for new multi-line format fields
    ml_agent_re = re.compile(r"^-\s*Agent:\s*(.+?)\s*$", re.IGNORECASE)
    ml_gate_re = re.compile(r"^-\s*(?:Result|Gate):\s*(.+?)\s*$", re.IGNORECASE)
    ml_msg_re = re.compile(r"^-\s*Message:\s*(.+?)\s*$", re.IGNORECASE)

    # First pass: scan frontmatter (between first --- delimiters) for iteration
    in_frontmatter = False
    frontmatter_done = False
    dash_count = 0
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "---" and not frontmatter_done:
            dash_count += 1
            if dash_count == 1:
                in_frontmatter = True
            elif dash_count == 2:
                in_frontmatter = False
                frontmatter_done = True
            continue
        if in_frontmatter:
            fm = frontmatter_iter_re.match(stripped)
            if fm:
                current_iter = int(fm.group(1))

    def _flush_pending(pending: dict) -> None:
        """Emit a row from accumulated multi-line fields if agent is set."""
        if pending.get("agent") and current_phase:
            rows.append((session_id, current_phase, current_iter,
                         pending["agent"], pending.get("gate"), pending.get("msg"), ts_now))

    # Second pass: scan all lines for phase headings and agent lines
    pending: dict = {}
    for line in text.splitlines():
        stripped = line.strip()

        # Old-format: phase + iteration on same line
        pm_old = old_phase_re.search(line)
        if pm_old:
            _flush_pending(pending)
            pending = {}
            current_phase = pm_old.group(1)
            current_iter = int(pm_old.group(2))
            continue

        # New-format: body phase heading (iteration already set from frontmatter)
        pm_new = body_phase_re.match(stripped)
        if pm_new:
            _flush_pending(pending)
            pending = {}
            current_phase = pm_new.group(1)
            continue

        # Update frontmatter iteration if encountered inline (handles multi-section files)
        fm = frontmatter_iter_re.match(stripped)
        if fm:
            current_iter = int(fm.group(1))
            continue

        # Old single-line agent format: - Agent: X | Gate: Y | msg
        am = agent_re.search(line)
        if am and current_phase:
            _flush_pending(pending)
            pending = {}
            rows.append((session_id, current_phase, current_iter,
                         am.group(1), am.group(2), am.group(3).strip(), ts_now))
            continue

        # New multi-line format — accumulate fields
        m_agent = ml_agent_re.match(stripped)
        if m_agent:
            # Starting a new agent block: flush any prior pending
            if pending.get("agent"):
                _flush_pending(pending)
                pending = {}
            pending["agent"] = m_agent.group(1)
            continue

        m_gate = ml_gate_re.match(stripped)
        if m_gate:
            pending["gate"] = m_gate.group(1)
            continue

        m_msg = ml_msg_re.match(stripped)
        if m_msg:
            pending["msg"] = m_msg.group(1)
            continue

    # Flush any remaining pending entry at EOF
    _flush_pending(pending)

    if rows:
        conn.executemany("""
            INSERT INTO iterations (session_id, phase, iteration_n, agent, gate_result, message, ts)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, rows)
        conn.commit()


# ---------------------------------------------------------------------------
# Subcommand: load
# ---------------------------------------------------------------------------

def cmd_load(args, conn: sqlite3.Connection) -> None:
    transcripts_dir = (
        pathlib.Path(args.transcripts_dir)
        if args.transcripts_dir
        else default_transcripts_dir()
    )

    if not transcripts_dir.exists():
        print(f"Error: transcripts directory not found: {transcripts_dir}", file=sys.stderr)
        print("  Use --transcripts-dir to specify the path explicitly.", file=sys.stderr)
        sys.exit(1)

    do_redact = getattr(args, "redact", False)
    show_stats = getattr(args, "stats", False)

    # Capture pre-load counts for --stats delta reporting
    before_counts: dict[str, int] = {}
    if show_stats:
        before_counts = load_counts_by_session(conn)

    if args.session:
        load_session(conn, args.session, transcripts_dir, do_redact)
        _parse_orchestration_log(conn, args.session)
    elif getattr(args, "all_sessions", False):
        # Find all session IDs: JSONL files at root or directories
        session_ids = set()
        for p in transcripts_dir.iterdir():
            if p.suffix == ".jsonl":
                sid = p.stem
                if SESSION_ID_RE.match(sid):
                    session_ids.add(sid)
            elif p.is_dir() and SESSION_ID_RE.match(p.name):
                session_ids.add(p.name)
        if not session_ids:
            print("No sessions found in transcripts dir.", file=sys.stderr)
        for sid in sorted(session_ids):
            load_session(conn, sid, transcripts_dir, do_redact)
        # Parse orchestration log once
        if session_ids:
            _parse_orchestration_log(conn, "local")
    else:
        print("Error: specify --session <id> or --all-sessions", file=sys.stderr)
        sys.exit(1)

    apply_views(conn)
    total = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
    sessions = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    print(f"Loaded {total} events across {sessions} sessions into {args.db}", file=sys.stderr)

    if show_stats:
        after_counts = load_counts_by_session(conn)
        all_sids = sorted(set(before_counts) | set(after_counts))
        print("\nPer-session event delta (--stats):", file=sys.stderr)
        print(f"  {'SESSION':<36}  {'BEFORE':>7}  {'AFTER':>7}  {'DELTA':>7}", file=sys.stderr)
        print(f"  {'-'*36}  {'-'*7}  {'-'*7}  {'-'*7}", file=sys.stderr)
        for sid in all_sids:
            before = before_counts.get(sid, 0)
            after = after_counts.get(sid, 0)
            delta = after - before
            marker = " *" if delta > 0 else ""
            print(f"  {sid:<36}  {before:>7}  {after:>7}  {delta:>7}{marker}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Subcommand: sessions
# ---------------------------------------------------------------------------

def cmd_sessions(args, conn: sqlite3.Connection) -> None:
    apply_views(conn)
    rows = conn.execute("""
        SELECT session_id, started_at, git_branch, event_count, subagents, agent_dispatches
        FROM v_session_summary
        ORDER BY started_at DESC
    """).fetchall()

    if not rows:
        print("No sessions found. Run: analyze load --all-sessions")
        return

    hdr = f"{'SESSION':<36}  {'STARTED':<20}  {'BRANCH':<20}  {'EVENTS':>6}  {'AGENTS':>6}  {'DISPATCHES':>10}"
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        started = (r["started_at"] or "")[:19]
        branch  = (r["git_branch"] or "")[:20]
        print(f"{r['session_id']:<36}  {started:<20}  {branch:<20}  {r['event_count'] or 0:>6}  "
              f"{r['subagents'] or 0:>6}  {r['agent_dispatches'] or 0:>10}")


# ---------------------------------------------------------------------------
# Subcommand: sql
# ---------------------------------------------------------------------------

def cmd_sql(args, conn: sqlite3.Connection) -> None:
    apply_views(conn)
    query = args.query
    try:
        cur = conn.execute(query)
    except sqlite3.Error as e:
        print(f"SQL error: {e}", file=sys.stderr)
        sys.exit(1)

    cols = [d[0] for d in cur.description] if cur.description else []
    rows = cur.fetchall()

    if not cols:
        print("(no columns returned)")
        return

    # Compute column widths
    widths = [len(c) for c in cols]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(str(val) if val is not None else ""))

    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    print(fmt.format(*cols))
    print("  ".join("-" * w for w in widths))
    for row in rows:
        vals = [str(v) if v is not None else "" for v in row]
        print(fmt.format(*vals))


# ---------------------------------------------------------------------------
# Agent allowlist parsing
# ---------------------------------------------------------------------------

def _parse_agent_tools(agents_dir: pathlib.Path) -> dict[str, set[str]]:
    """Parse agents/*.md YAML frontmatter for tools: list. Returns {agent_name: {tool, ...}}."""
    result: dict[str, set[str]] = {}
    if not agents_dir.exists():
        return result
    for md in agents_dir.glob("*.md"):
        text = md.read_text(errors="replace")
        # Extract YAML frontmatter
        if not text.startswith("---"):
            continue
        end = text.find("---", 3)
        if end == -1:
            continue
        fm = text[3:end]
        # Find tools: list (simple line-by-line parse)
        in_tools = False
        tools: set[str] = set()
        for line in fm.splitlines():
            stripped = line.strip()
            if stripped.startswith("tools:"):
                in_tools = True
                # inline: tools: [a, b]
                m = re.search(r"\[([^\]]+)\]", stripped)
                if m:
                    tools.update(t.strip().strip('"\'') for t in m.group(1).split(","))
                    in_tools = False
                continue
            if in_tools:
                if stripped.startswith("-"):
                    tools.add(stripped[1:].strip().strip('"\''))
                elif stripped and not stripped.startswith("#"):
                    in_tools = False
        # Also grab model if present
        agent_name = md.stem
        if tools:
            result[agent_name] = tools
    return result


def _parse_agent_models(agents_dir: pathlib.Path) -> dict[str, str]:
    """Parse agents/*.md YAML frontmatter for model: field."""
    result: dict[str, str] = {}
    if not agents_dir.exists():
        return result
    for md in agents_dir.glob("*.md"):
        text = md.read_text(errors="replace")
        if not text.startswith("---"):
            continue
        end = text.find("---", 3)
        if end == -1:
            continue
        fm = text[3:end]
        for line in fm.splitlines():
            m = re.match(r"model:\s*(.+)", line.strip())
            if m:
                result[md.stem] = m.group(1).strip().strip('"\'')
                break
    return result


# ---------------------------------------------------------------------------
# Subcommand: report
# ---------------------------------------------------------------------------

def _table(headers: list[str], rows: list[list], max_rows: int = REPORT_TOP_N) -> str:
    """Render a markdown table."""
    truncated = len(rows) > max_rows
    rows = rows[:max_rows]
    if not rows:
        return "_No data._\n"
    widths = [len(h) for h in headers]
    for row in rows:
        for i, v in enumerate(row):
            widths[i] = max(widths[i], len(str(v)))
    fmt = "| " + " | ".join(f"{{:<{w}}}" for w in widths) + " |"
    sep = "| " + " | ".join("-" * w for w in widths) + " |"
    lines = [fmt.format(*headers), sep]
    for row in rows:
        lines.append(fmt.format(*[str(v) for v in row]))
    if truncated:
        lines.append(f"_... (showing top {max_rows} rows)_")
    return "\n".join(lines) + "\n"


_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def _strip_ansi(text: str) -> str:
    return _ANSI_RE.sub("", text)


def _hook_event_insights(conn: sqlite3.Connection) -> list[str]:
    """
    M4c: Return list of insight strings based on PreToolUse/PostToolUse hook events.
    These are added to the improvement opportunities section.
    """
    insights: list[str] = []

    # 1. Count PreToolUse → PostToolUse pairs per tool (via decision column / hook_event info).
    #    We approximate using events where tool_name is set and decision is present.
    #    Better: check attachment hookEvent field stored in decision column.
    #    Since we store the decision from attachments, count unmatched by checking
    #    PreToolUse events with decision='block' vs total PreToolUse per tool.
    #    Fallback: use ad-hoc count from events table (tool_use_id correlation).

    # Count sessions with no ended_at
    no_end = conn.execute(
        "SELECT COUNT(*) FROM sessions WHERE ended_at IS NULL OR ended_at = ''"
    ).fetchone()[0]
    if no_end and no_end > 0:
        insights.append(
            f"- **{no_end} session(s)** have no `ended_at` timestamp — "
            f"session didn't terminate cleanly (informational)."
        )

    # 2. Subagents with no tool_use_id (SubagentStop without resolution)
    unresolved = conn.execute(
        "SELECT COUNT(DISTINCT agent_id) FROM subagents WHERE agent_id IS NOT NULL"
        " AND agent_id NOT IN ("
        "  SELECT DISTINCT agent_id FROM events WHERE tool_use_id IS NOT NULL AND agent_id IS NOT NULL"
        ")"
    ).fetchone()[0]
    if unresolved and unresolved > 0:
        insights.append(
            f"- **{unresolved} subagent(s)** have no matched `tool_use_id` in events "
            f"(SubagentStop without resolution — usually fine)."
        )

    # 3. Tool abort rate: PreToolUse with no matching PostToolUse
    #    We approximate via tool_name call counts vs result counts.
    tool_use_counts = {
        r[0]: r[1]
        for r in conn.execute(
            "SELECT tool_name, COUNT(*) FROM events "
            "WHERE tool_use_id IS NOT NULL AND tool_name IS NOT NULL AND tool_result_json IS NULL "
            "GROUP BY tool_name"
        ).fetchall()
    }
    tool_result_counts = {
        r[0]: r[1]
        for r in conn.execute(
            "SELECT e2.tool_name, COUNT(*) FROM events e1 "
            "JOIN events e2 ON e1.tool_use_id = e2.tool_use_id "
            "WHERE e1.tool_result_json IS NOT NULL AND e2.tool_name IS NOT NULL "
            "GROUP BY e2.tool_name"
        ).fetchall()
    }
    for tool, use_count in tool_use_counts.items():
        result_count = tool_result_counts.get(tool, 0)
        if use_count > 0:
            unmatched_rate = max(0, use_count - result_count) / use_count
            if unmatched_rate > 0.10:
                insights.append(
                    f"- **`{tool}`** has {unmatched_rate:.0%} unmatched tool calls "
                    f"({use_count - result_count}/{use_count} pre without post) — "
                    f"check permission or timeout."
                )

    return insights


def cmd_report(args, conn: sqlite3.Connection) -> None:
    apply_views(conn)

    # M4a: optional session filter
    session_filter: str | None = getattr(args, "session", None)

    def _session_where(alias: str = "session_id") -> str:
        return f"AND {alias} = ?" if session_filter else ""

    def _session_params() -> tuple:
        return (session_filter,) if session_filter else ()

    sections = []
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # ---- Session overview ----
    q = "SELECT session_id, started_at, ended_at, git_branch, event_count, subagents, agent_dispatches FROM v_session_summary"
    if session_filter:
        q += " WHERE session_id = ?"
        sessions_rows = conn.execute(q, (session_filter,)).fetchall()
    else:
        q += " ORDER BY started_at DESC"
        sessions_rows = conn.execute(q).fetchall()

    title = "# agent-flow Observability Report"
    if session_filter:
        title += f" — session {session_filter[:8]}…"
    sections.append(title + "\n")
    sections.append(f"_Generated: {now}_\n")

    sections.append("## Session Overview\n")
    if sessions_rows:
        tbl = _table(
            ["session_id", "started_at", "branch", "events", "subagents", "dispatches"],
            [[r["session_id"][:8]+"…", (r["started_at"] or "")[:16],
              r["git_branch"] or "", r["event_count"] or 0,
              r["subagents"] or 0, r["agent_dispatches"] or 0]
             for r in sessions_rows]
        )
        sections.append(tbl)
    else:
        sections.append("_No sessions loaded. Run: `analyze load --all-sessions`_\n")

    # ---- Tool usage by agent ----
    sections.append("## Tool Usage by Agent\n")
    if session_filter:
        tool_rows = conn.execute(
            "SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type, tool_name, COUNT(*) AS n "
            "FROM events WHERE tool_name IS NOT NULL AND session_id=? "
            "GROUP BY agent_type, tool_name ORDER BY agent_type, n DESC",
            (session_filter,)
        ).fetchall()
    else:
        tool_rows = conn.execute("SELECT agent_type, tool_name, n FROM v_tool_usage_by_agent").fetchall()
    sections.append(_table(
        ["agent_type", "tool_name", "count"],
        [[r["agent_type"], r["tool_name"], r["n"]] for r in tool_rows]
    ))

    # ---- Skill / MCP invocations ----
    sections.append("## Skill / MCP Invocations by Agent\n")
    if session_filter:
        skill_rows = conn.execute(
            "SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type, tool_name, COUNT(*) AS n "
            "FROM events WHERE (tool_name LIKE 'mcp__%' OR tool_name = 'Skill') AND session_id=? "
            "GROUP BY agent_type, tool_name ORDER BY agent_type, n DESC",
            (session_filter,)
        ).fetchall()
    else:
        skill_rows = conn.execute("SELECT agent_type, tool_name, n FROM v_skill_invocations").fetchall()
    if skill_rows:
        sections.append(_table(
            ["agent_type", "tool_name", "count"],
            [[r["agent_type"], r["tool_name"], r["n"]] for r in skill_rows]
        ))
    else:
        sections.append("_No MCP/Skill invocations found._\n")

    # ---- Thinking effort ----
    sections.append("## Thinking Effort by Agent\n")
    if session_filter:
        think_rows = conn.execute(
            "SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type, "
            "COUNT(*) AS thinking_events, SUM(LENGTH(thinking_text)) AS total_chars, "
            "AVG(LENGTH(thinking_text)) AS avg_chars FROM events "
            "WHERE thinking_text IS NOT NULL AND thinking_text != '' AND session_id=? "
            "GROUP BY agent_type ORDER BY total_chars DESC",
            (session_filter,)
        ).fetchall()
    else:
        think_rows = conn.execute("""
            SELECT agent_type, thinking_events, total_chars, ROUND(avg_chars,0) AS avg_chars
            FROM v_thinking_by_agent ORDER BY total_chars DESC
        """).fetchall()
    if think_rows:
        sections.append(_table(
            ["agent_type", "events", "total_chars", "avg_chars"],
            [[r["agent_type"], r["thinking_events"], r["total_chars"], r["avg_chars"]]
             for r in think_rows]
        ))
    else:
        sections.append("_No thinking blocks found._\n")

    # ---- Token usage ----
    sections.append("## Token Usage by Agent / Model\n")
    if session_filter:
        token_rows = conn.execute(
            "SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type, model, "
            "COUNT(*) AS events, SUM(input_tokens) AS input, SUM(output_tokens) AS output, "
            "SUM(cache_read_tokens) AS cache_read, SUM(cache_creation_tokens) AS cache_creation "
            "FROM events WHERE role='assistant' AND session_id=? "
            "GROUP BY agent_type, model ORDER BY agent_type, input DESC",
            (session_filter,)
        ).fetchall()
    else:
        token_rows = conn.execute("""
            SELECT agent_type, model, events, input, output, cache_read, cache_creation
            FROM v_tokens_by_agent ORDER BY agent_type, input DESC
        """).fetchall()
    if token_rows:
        sections.append(_table(
            ["agent_type", "model", "events", "input", "output", "cache_read", "cache_create"],
            [[r["agent_type"], r["model"] or "", r["events"],
              r["input"] or 0, r["output"] or 0, r["cache_read"] or 0, r["cache_creation"] or 0]
             for r in token_rows]
        ))
    else:
        sections.append("_No token data found._\n")

    # ---- Subagent dispatches & iteration rate ----
    sections.append("## Subagent Dispatches & Iteration Rate\n")
    iter_rows = conn.execute("""
        SELECT subagent_type, total_dispatches, sessions, dispatches_per_session
        FROM v_iteration_rate ORDER BY dispatches_per_session DESC
    """).fetchall()
    if iter_rows:
        sections.append(_table(
            ["subagent_type", "total_dispatches", "sessions", "per_session"],
            [[r["subagent_type"], r["total_dispatches"], r["sessions"], r["dispatches_per_session"]]
             for r in iter_rows]
        ))
    else:
        sections.append("_No Agent/Task dispatches recorded._\n")

    # ---- Rejection rate ----
    sections.append("## Rejection Rate (Stop-hook decisions)\n")
    if session_filter:
        reject_rows = conn.execute(
            "SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type, "
            "SUM(CASE WHEN decision='block' THEN 1 ELSE 0 END) AS blocks, "
            "SUM(CASE WHEN decision='approve' THEN 1 ELSE 0 END) AS approves, "
            "SUM(CASE WHEN decision='deny' THEN 1 ELSE 0 END) AS denies, "
            "COUNT(decision) AS decided FROM events WHERE decision IS NOT NULL AND session_id=? "
            "GROUP BY agent_type ORDER BY blocks DESC",
            (session_filter,)
        ).fetchall()
    else:
        reject_rows = conn.execute("""
            SELECT agent_type, blocks, approves, denies, decided FROM v_rejection_rate
            ORDER BY blocks DESC
        """).fetchall()
    if reject_rows:
        sections.append(_table(
            ["agent_type", "blocks", "approves", "denies", "decided"],
            [[r["agent_type"], r["blocks"], r["approves"], r["denies"], r["decided"]]
             for r in reject_rows]
        ))
    else:
        sections.append("_No hook decisions recorded._\n")

    # ---- Improvement opportunities ----
    sections.append("## Improvement Opportunities\n")
    opportunities: list[str] = []

    # 1. High iteration rate
    for r in iter_rows:
        rate = float(r["dispatches_per_session"]) if r["dispatches_per_session"] else 0.0
        if rate > 2.5:
            opportunities.append(
                red(f"- **{r['subagent_type']}** has {r['dispatches_per_session']} dispatches/session "
                    f"(>{2.5}): check prompt clarity / verification gates.")
            )
        elif rate > 1.5:
            opportunities.append(
                yellow(f"- **{r['subagent_type']}** has {r['dispatches_per_session']} dispatches/session "
                       f"(>{1.5}): check prompt clarity / verification gates.")
            )

    # 2. High block rate
    for r in reject_rows:
        if r["decided"] and r["decided"] > 0:
            block_rate = (r["blocks"] or 0) / r["decided"]
            if block_rate > 0.5:
                opportunities.append(
                    red(f"- **{r['agent_type']}** block rate {block_rate:.0%} ({r['blocks']}/{r['decided']}): "
                        f"review verification-hook strictness or agent output contract.")
                )
            elif block_rate > 0.3:
                opportunities.append(
                    yellow(f"- **{r['agent_type']}** block rate {block_rate:.0%} ({r['blocks']}/{r['decided']}): "
                           f"review verification-hook strictness or agent output contract.")
                )

    # 3. Unused tools from allowlist / tools used outside allowlist
    agents_dir = pathlib.Path("agents")
    declared_tools = _parse_agent_tools(agents_dir)

    # Map agent_type (e.g. "agent-flow:Loid") to agent name ("Loid")
    def _agent_name(at: str) -> str:
        return at.split(":")[-1] if at else ""

    used_tools_by_agent: dict[str, set[str]] = collections.defaultdict(set)
    base_q = "SELECT agent_type, tool_name FROM events WHERE tool_name IS NOT NULL AND agent_type IS NOT NULL"
    if session_filter:
        base_q += " AND session_id=?"
        tool_ev_rows = conn.execute(base_q, (session_filter,)).fetchall()
    else:
        tool_ev_rows = conn.execute(base_q).fetchall()
    for r in tool_ev_rows:
        used_tools_by_agent[_agent_name(r["agent_type"])].add(r["tool_name"])

    for agent_name, allowed in declared_tools.items():
        used = used_tools_by_agent.get(agent_name, set())
        unused = allowed - used
        overreach = used - allowed
        if unused:
            opportunities.append(
                f"- **{agent_name}**: tools in allowlist but never invoked: "
                + ", ".join(f"`{t}`" for t in sorted(unused))
                + " — consider removing from allowlist."
            )
        if overreach:
            opportunities.append(
                f"- **{agent_name}**: tools invoked but NOT in declared allowlist: "
                + ", ".join(f"`{t}`" for t in sorted(overreach))
                + " — check agent definition."
            )

    # 4. Riko/Senku/Lawliet with no MCP invocations
    graph_agents = {"Riko", "Senku", "Lawliet"}
    for ag in graph_agents:
        if ag in used_tools_by_agent:
            mcp_used = {t for t in used_tools_by_agent[ag] if t.startswith("mcp__")}
            if not mcp_used:
                opportunities.append(
                    f"- **{ag}** has zero `mcp__*` invocations: not using graph/personal-kb. "
                    f"Check if graphify MCP server is running."
                )

    # 5. Model mismatch
    declared_models = _parse_agent_models(agents_dir)
    model_q = (
        "SELECT agent_type, model FROM events WHERE model IS NOT NULL AND agent_type IS NOT NULL "
        "GROUP BY agent_type ORDER BY COUNT(*) DESC"
    )
    actual_models = {
        _agent_name(r["agent_type"]): r["model"]
        for r in conn.execute(model_q).fetchall()
        if r["agent_type"]
    }
    for agent_name, declared_model in declared_models.items():
        actual = actual_models.get(agent_name)
        if actual:
            alias = declared_model.lower()
            prefix = MODEL_ALIAS_PREFIX.get(alias)
            if prefix is not None:
                if not actual.startswith(prefix):
                    opportunities.append(
                        f"- **{agent_name}**: declared model `{declared_model}` but events show `{actual}` — "
                        f"verify model routing."
                    )
            elif actual != declared_model:
                opportunities.append(
                    f"- **{agent_name}**: declared model `{declared_model}` but events show `{actual}` — "
                    f"verify model routing."
                )

    # 6. M4c: hook event insights
    opportunities.extend(_hook_event_insights(conn))

    # ---- Suppressed findings collector ----
    suppressed_findings: list[str] = []

    # 7. Fan-out whitelist (#4): suppress "zero MCP calls" Riko findings
    #    if ALL dispatch descriptions match a whitelist of benign fan-out patterns.
    FAN_OUT_WHITELIST = [
        re.compile(r"Semantic extract chunk \d+", re.I),
        re.compile(r"literal-text probe", re.I),
    ]

    def _matches_whitelist(desc: str) -> bool:
        return any(p.search(desc or "") for p in FAN_OUT_WHITELIST)

    # Re-evaluate Riko zero-MCP finding with whitelist suppression
    if "Riko" in used_tools_by_agent:
        mcp_used_riko = {t for t in used_tools_by_agent["Riko"] if t.startswith("mcp__")}
        if not mcp_used_riko:
            # Check if all Riko dispatches match the whitelist
            riko_descs = conn.execute(
                "SELECT description FROM subagents WHERE agent_type LIKE '%Riko%' AND description IS NOT NULL"
            ).fetchall()
            if riko_descs and all(_matches_whitelist(r["description"]) for r in riko_descs):
                # Remove the Riko zero-MCP finding that was added in heuristic 4 above
                opportunities[:] = [
                    o for o in opportunities
                    if "**Riko** has zero `mcp__*` invocations" not in o
                ]
                suppressed_findings.append(
                    "- **Riko** zero-MCP finding suppressed: all dispatches matched fan-out whitelist "
                    f"({len(riko_descs)} dispatch(es))."
                )

    # 8a. Orchestrator IO volume (#8a)
    orch_io_q = (
        "SELECT COUNT(*) AS n FROM events "
        "WHERE (agent_type IS NULL OR agent_type = '') "
        "AND tool_name IN ('Read','Grep','Glob','Edit','Write')"
    )
    orch_io_count = conn.execute(orch_io_q).fetchone()["n"]
    if orch_io_count > 50:
        opportunities.append(
            red(f"- **<orchestrator>** made {orch_io_count} direct Read/Grep/Glob/Edit/Write calls "
                f"(>50): orchestrator is doing too much inline work — delegate to Riko/Loid.")
        )

    # Check average cache_read per turn for orchestrator
    orch_cache_q = (
        "SELECT AVG(cache_read_tokens) AS avg_cr FROM events "
        "WHERE (agent_type IS NULL OR agent_type = '') "
        "AND role = 'assistant' AND cache_read_tokens IS NOT NULL"
    )
    orch_cache_row = conn.execute(orch_cache_q).fetchone()
    if orch_cache_row and orch_cache_row["avg_cr"] and float(orch_cache_row["avg_cr"]) > 80_000:
        opportunities.append(
            yellow(f"- **<orchestrator>** average cache_read/turn is "
                   f"{int(float(orch_cache_row['avg_cr'])):,} tokens (>80 000): "
                   f"excessive context replay — split into sub-phases or delegate earlier.")
        )

    # 8b. MCP-skipping per task type (#8b)
    arch_re = re.compile(r"architecture|map|cross-cutting|structure|graph", re.I)
    arch_dispatches = conn.execute(
        "SELECT agent_id, description FROM subagents "
        "WHERE agent_type LIKE '%Riko%' AND description IS NOT NULL"
    ).fetchall()
    for row in arch_dispatches:
        if not arch_re.search(row["description"] or ""):
            continue
        # Check if this specific subagent used any mcp__ tool
        mcp_count = conn.execute(
            "SELECT COUNT(*) AS n FROM events "
            "WHERE agent_id = ? AND tool_name LIKE 'mcp__%'",
            (row["agent_id"],)
        ).fetchone()["n"]
        if mcp_count == 0 and not _matches_whitelist(row["description"]):
            opportunities.append(
                yellow(f"- **Riko** dispatch matching architecture/graph pattern made zero MCP calls: "
                       f"\"{(row['description'] or '')[:80]}\". "
                       f"Use graphify tools for structural exploration.")
            )

    # 8c. decision-NULL regression guard (#8c)
    decision_not_null = conn.execute(
        "SELECT COUNT(*) AS n FROM events WHERE decision IS NOT NULL"
    ).fetchone()["n"]
    # Check for PreToolUse events — column may not exist in older DBs
    try:
        pre_tool_use_count = conn.execute(
            "SELECT COUNT(*) AS n FROM events WHERE hook_event = 'PreToolUse'"
        ).fetchone()["n"]
    except Exception:
        pre_tool_use_count = 0
    if decision_not_null == 0 and pre_tool_use_count > 0:
        opportunities.append(
            red("- **Observability regression**: `decision` column is 100% NULL despite "
                f"{pre_tool_use_count} PreToolUse event(s). "
                "Check `hooks/scripts/log-event.py:94-107`.")
        )

    # 8d. iterations-empty regression guard (#8d)
    iter_count = conn.execute("SELECT COUNT(*) AS n FROM iterations").fetchone()["n"]
    dispatch_count = conn.execute("SELECT COUNT(*) AS n FROM subagents").fetchone()["n"]
    if iter_count == 0 and dispatch_count >= 10:
        opportunities.append(
            red(f"- **Observability regression**: `iterations` table is empty despite "
                f"{dispatch_count} dispatch(es). "
                "Check analyze.py iteration parser at `scripts/analyze/analyze.py:472-508`.")
        )

    if opportunities:
        # Summary line in green
        summary = green(f"- {len(opportunities)} opportunity/ies found — see above for details.")
        all_ops = "\n".join(opportunities)
        sections.append(all_ops + "\n" + summary + "\n")
    else:
        sections.append(green("_No improvement opportunities detected._") + "\n")

    # ---- Suppressed findings ----
    if suppressed_findings:
        sections.append("## Suppressed Findings\n")
        sections.append("_The following findings were detected but suppressed by whitelist rules:_\n")
        sections.append("\n".join(suppressed_findings) + "\n")

    # ---- Assemble report (terminal version with ANSI) ----
    report_terminal = "\n".join(sections)

    # Strip ANSI for the file version
    report_file = _strip_ansi(report_terminal)

    # Write to file
    report_path = pathlib.Path(".claude/observability/report.md")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report_file)
    print(f"[report] written to {report_path}", file=sys.stderr)

    # M4a: also write per-session file if --session was given
    if session_filter:
        session_report_path = pathlib.Path(f".claude/observability/{session_filter}.md")
        session_report_path.write_text(report_file)
        print(f"[report] written to {session_report_path}", file=sys.stderr)

    # Print to stdout (with ANSI if TTY)
    print(report_terminal)


# ---------------------------------------------------------------------------
# Subcommand: retention
# ---------------------------------------------------------------------------

def cmd_retention(args, conn: sqlite3.Connection) -> None:
    """Delete old events and optionally vacuum the database."""
    days = getattr(args, "days", None)
    wipe_all = getattr(args, "all", False)

    if not wipe_all and days is None:
        print("Error: specify --days N or --all", file=sys.stderr)
        sys.exit(1)

    if wipe_all:
        count_events = conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        count_subagents = conn.execute("SELECT COUNT(*) FROM subagents").fetchone()[0]
        conn.execute("DELETE FROM events")
        conn.execute("DELETE FROM subagents")
        conn.commit()
        conn.execute("VACUUM")
        print(f"Wiped {count_events} events and {count_subagents} subagents from database.")
    else:
        assert days is not None
        cutoff = (
            datetime.datetime.now(datetime.timezone.utc)
            - datetime.timedelta(days=int(days))
        ).strftime("%Y-%m-%dT%H:%M:%SZ")
        count = conn.execute(
            "SELECT COUNT(*) FROM events WHERE ts < ?", (cutoff,)
        ).fetchone()[0]
        conn.execute("DELETE FROM events WHERE ts < ?", (cutoff,))
        conn.commit()
        conn.execute("VACUUM")
        print(f"Deleted {count} events older than {days} days (cutoff: {cutoff}).")


# ---------------------------------------------------------------------------
# Subcommand: label (M5)
# ---------------------------------------------------------------------------

_VERDICTS = {"c": "correct", "m": "missed", "e": "extra", "w": "wrong"}


def cmd_label(args, conn: sqlite3.Connection) -> None:
    """Interactive labeling UI for subagent recall evaluation."""
    session_id = args.session_id
    if not SESSION_ID_RE.match(session_id):
        print(f"Error: invalid session ID {session_id!r}", file=sys.stderr)
        sys.exit(2)

    apply_views(conn)

    # Load subagents for this session in dispatch order (spawned_at)
    agents = conn.execute(
        "SELECT agent_id, agent_type, description, input_prompt, accepted_output "
        "FROM subagents WHERE session_id=? ORDER BY spawned_at ASC",
        (session_id,)
    ).fetchall()

    if not agents:
        print(f"No subagents found for session {session_id}.")
        return

    # Skip already-labeled (agent_id, session_id) pairs
    labeled_ids = {
        r[0] for r in conn.execute(
            "SELECT agent_id FROM labels WHERE session_id=? AND agent_id IS NOT NULL",
            (session_id,)
        ).fetchall()
    }

    to_label = [a for a in agents if a["agent_id"] not in labeled_ids]
    total = len(agents)
    labeled_count = total - len(to_label)

    if not to_label:
        print(f"All {total} subagents for session {session_id} are already labeled.")
        _print_label_summary(conn, session_id)
        return

    print(f"\nLabeling session {session_id} — {len(to_label)} subagents to label ({labeled_count} already done)\n")
    print("Verdict keys: [c]orrect / [m]issed / [e]xtra / [w]rong / [s]kip / [q]uit")
    print("  You may add a note after a space, e.g.: 'm needs more detail on X'\n")

    verdict_counts: dict[str, int] = {"correct": 0, "missed": 0, "extra": 0, "wrong": 0, "skipped": 0}
    ts_now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    for idx, agent in enumerate(to_label, start=labeled_count + 1):
        agent_id = agent["agent_id"]
        agent_type = agent["agent_type"] or ""
        description = agent["description"] or ""
        input_prompt = (agent["input_prompt"] or "")[:300]
        accepted_output = (agent["accepted_output"] or "")[:500]

        print(f"[{idx}/{total}] {agent_type}  — \"{description}\"")
        if input_prompt:
            print(f"Input prompt (first 300 chars): {input_prompt}")
        if accepted_output:
            print(f"Accepted output (first 500 chars): {accepted_output}")
        print()

        while True:
            try:
                raw = input("verdict ([c/m/e/w/s/q] [note]): ").strip()
            except (EOFError, KeyboardInterrupt):
                raw = "q"

            if not raw:
                continue

            key = raw[0].lower()
            note = raw[2:].strip() if len(raw) > 1 else ""

            if key == "q":
                print("\nQuit — progress saved.")
                _print_label_summary(conn, session_id)
                return
            elif key == "s":
                verdict_counts["skipped"] += 1
                print("  → skipped\n")
                break
            elif key in _VERDICTS:
                verdict = _VERDICTS[key]
                label_id = str(_uuid_mod.uuid4())
                conn.execute(
                    "INSERT INTO labels (label_id, session_id, agent_id, agent_type, verdict, note, ts) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (label_id, session_id, agent_id, agent_type, verdict, note or None, ts_now)
                )
                conn.commit()
                verdict_counts[verdict] += 1
                print(f"  → {verdict}" + (f" ({note})" if note else "") + "\n")
                break
            else:
                print("  Invalid key — use c/m/e/w/s/q")

    print("Session complete!")
    _print_label_summary(conn, session_id)


def _print_label_summary(conn: sqlite3.Connection, session_id: str) -> None:
    rows = conn.execute(
        "SELECT verdict, COUNT(*) AS n FROM labels WHERE session_id=? GROUP BY verdict",
        (session_id,)
    ).fetchall()
    counts = {r["verdict"]: r["n"] for r in rows}
    total = sum(counts.values())
    print(f"\nLabel summary for session {session_id[:8]}…:")
    for v in ("correct", "missed", "extra", "wrong"):
        print(f"  {v}: {counts.get(v, 0)}")
    print(f"  total: {total}")


def cmd_label_export(args, conn: sqlite3.Connection) -> None:
    """Export labels as CSV with precision/recall_proxy metrics."""
    apply_views(conn)

    session_id = getattr(args, "session_id", None)
    export_all = getattr(args, "all", False)

    if session_id:
        if not SESSION_ID_RE.match(session_id):
            print(f"Error: invalid session ID {session_id!r}", file=sys.stderr)
            sys.exit(2)
        rows = conn.execute(
            "SELECT session_id, agent_type, verdict FROM labels WHERE session_id=?",
            (session_id,)
        ).fetchall()
    elif export_all:
        rows = conn.execute(
            "SELECT session_id, agent_type, verdict FROM labels"
        ).fetchall()
    else:
        print("Error: specify session_id or --all", file=sys.stderr)
        sys.exit(1)

    # Aggregate by (session_id, agent_type)
    agg: dict[tuple[str, str], dict[str, int]] = {}
    for r in rows:
        key = (r["session_id"], r["agent_type"] or "")
        if key not in agg:
            agg[key] = {"correct": 0, "missed": 0, "extra": 0, "wrong": 0}
        if r["verdict"] in agg[key]:
            agg[key][r["verdict"]] += 1

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "session_id", "agent_type", "labeled_count",
        "correct", "missed", "extra", "wrong",
        "precision", "recall_proxy"
    ])

    for (sid, agent_type), counts in sorted(agg.items()):
        c = counts["correct"]
        m = counts["missed"]
        e = counts["extra"]
        w = counts["wrong"]
        labeled = c + m + e + w
        prec_denom = c + e + w
        rec_denom = c + m
        precision = round(c / prec_denom, 4) if prec_denom > 0 else ""
        recall_proxy = round(c / rec_denom, 4) if rec_denom > 0 else ""
        writer.writerow([sid, agent_type, labeled, c, m, e, w, precision, recall_proxy])

    csv_content = output.getvalue()
    print(csv_content, end="")

    # Write to file
    out_path = pathlib.Path(".claude/observability/labels-export.csv")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(csv_content)
    print(f"[label export] written to {out_path}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Subcommand: export (M6)
# ---------------------------------------------------------------------------

OBSERVABILITY_CONFIG = pathlib.Path(".claude/observability.json")


def cmd_export(args, conn: sqlite3.Connection) -> None:
    """Export events via configured exporter plugins."""
    from exporters import load_exporters, ExporterUnavailable

    if not OBSERVABILITY_CONFIG.exists():
        print("no exporters configured")
        return

    try:
        config = json.loads(OBSERVABILITY_CONFIG.read_text())
    except (json.JSONDecodeError, OSError) as e:
        print(f"Error reading {OBSERVABILITY_CONFIG}: {e}", file=sys.stderr)
        sys.exit(1)

    exporter_name_filter = getattr(args, "exporter", None)
    session_filter = getattr(args, "session", None)

    exporters = load_exporters(config)
    if not exporters:
        print("no exporters configured")
        return

    # Fetch events
    if session_filter:
        if not SESSION_ID_RE.match(session_filter):
            print(f"Error: invalid session ID {session_filter!r}", file=sys.stderr)
            sys.exit(2)
        event_rows = conn.execute(
            "SELECT * FROM events WHERE session_id=? ORDER BY ts ASC",
            (session_filter,)
        ).fetchall()
    else:
        event_rows = conn.execute("SELECT * FROM events ORDER BY ts ASC").fetchall()

    events = [dict(r) for r in event_rows]

    for exporter in exporters:
        if exporter_name_filter and exporter.name != exporter_name_filter:
            continue
        try:
            count = exporter.export(iter(events))
            # Determine output path for summary
            exp_cfg = config.get(exporter.name, {})
            out_path = exp_cfg.get("path", f".claude/observability/{exporter.name}-export")
            print(f"{exporter.name}: exported {count} events to {out_path}")
        except ExporterUnavailable as e:
            warn = f"[warn] exporter '{exporter.name}' unavailable: {e}"
            # Print yellow if color available
            try:
                from _ansi import yellow as _yellow
                print(_yellow(warn))
            except ImportError:
                print(warn)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="analyze",
        description="agent-flow transcript analyzer — offline observability for Claude Code sessions.",
    )
    parser.add_argument(
        "--db",
        default=str(DEFAULT_DB),
        help=f"SQLite database path (default: {DEFAULT_DB})",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # load
    p_load = sub.add_parser("load", help="Parse transcripts into the SQLite database.")
    p_load.add_argument("--transcripts-dir", help="Override transcript directory.")
    grp = p_load.add_mutually_exclusive_group()
    grp.add_argument("--session", metavar="ID", help="Load only this session ID.")
    grp.add_argument("--all-sessions", action="store_true", help="Load all sessions.")
    p_load.add_argument(
        "--redact",
        action="store_true",
        help="Mask credential patterns (AWS keys, OpenAI keys, GitHub PATs) before storing.",
    )
    p_load.add_argument(
        "--stats",
        action="store_true",
        help="Print per-session event delta after loading.",
    )

    # report
    p_report = sub.add_parser("report", help="Print markdown report to stdout and .claude/observability/report.md.")
    p_report.add_argument("--session", metavar="ID", help="Restrict report to one session.")

    # sessions
    sub.add_parser("sessions", help="List sessions with event counts.")

    # sql
    p_sql = sub.add_parser("sql", help="Run ad-hoc SQL and pretty-print results.")
    p_sql.add_argument("query", help="SQL query string.")

    # label (M5)
    # Usage: analyze label <session_id>
    #        analyze label export <session_id>
    #        analyze label export --all
    p_label = sub.add_parser("label", help="Interactive subagent labeling for recall evaluation.")
    p_label.add_argument("label_args", nargs=argparse.REMAINDER,
                         help="<session_id> OR 'export' <session_id> OR 'export --all'")

    # export (M6)
    p_export = sub.add_parser("export", help="Export events via configured exporter plugins.")
    p_export.add_argument("--exporter", metavar="NAME", help="Run only this exporter.")
    p_export.add_argument("--session", metavar="ID", help="Export only this session's events.")

    # retention
    p_ret = sub.add_parser("retention", help="Delete old events from the database.")
    ret_grp = p_ret.add_mutually_exclusive_group(required=True)
    ret_grp.add_argument(
        "--days",
        type=int,
        metavar="N",
        help="Delete events older than N days.",
    )
    ret_grp.add_argument(
        "--all",
        action="store_true",
        help="Wipe all events and subagents from the database.",
    )

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    # Validate --session UUID at parse time before any file I/O
    if getattr(args, "session", None) and not SESSION_ID_RE.match(args.session):
        print(
            f"Error: invalid session ID {args.session!r} — expected UUID format [0-9a-f-]{{36}}",
            file=sys.stderr,
        )
        sys.exit(2)

    db_path = pathlib.Path(args.db)
    conn = open_db(db_path)

    try:
        if args.command == "load":
            cmd_load(args, conn)
        elif args.command == "report":
            # Validate --session on report subcommand
            if getattr(args, "session", None) and not SESSION_ID_RE.match(args.session):
                print(
                    f"Error: invalid session ID {args.session!r} — expected UUID format [0-9a-f-]{{36}}",
                    file=sys.stderr,
                )
                sys.exit(2)
            cmd_report(args, conn)
        elif args.command == "sessions":
            cmd_sessions(args, conn)
        elif args.command == "sql":
            cmd_sql(args, conn)
        elif args.command == "retention":
            cmd_retention(args, conn)
        elif args.command == "label":
            # Parse label_args manually:
            #   label <session_id>            -> cmd_label
            #   label export <session_id>     -> cmd_label_export(session_id)
            #   label export --all            -> cmd_label_export(all=True)
            label_args = getattr(args, "label_args", [])
            if not label_args:
                print("Usage: analyze label <session_id>  OR  analyze label export [<session_id>|--all]",
                      file=sys.stderr)
                sys.exit(1)

            if label_args[0] == "export":
                # Build a fake args namespace for cmd_label_export
                rest = label_args[1:]
                class _LabelExportArgs:
                    session_id: str | None = None
                    all: bool = False
                le_args = _LabelExportArgs()
                if "--all" in rest:
                    le_args.all = True
                    le_args.session_id = None
                elif rest:
                    le_args.session_id = rest[0]
                    le_args.all = False
                else:
                    print("Usage: analyze label export <session_id>  OR  analyze label export --all",
                          file=sys.stderr)
                    sys.exit(1)
                cmd_label_export(le_args, conn)
            else:
                # label <session_id>
                class _LabelArgs:
                    session_id: str = label_args[0]
                cmd_label(_LabelArgs(), conn)
        elif args.command == "export":
            cmd_export(args, conn)
        else:
            parser.print_help()
            sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

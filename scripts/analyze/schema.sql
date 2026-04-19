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

CREATE TABLE IF NOT EXISTS subagents (
  agent_id           TEXT PRIMARY KEY,
  session_id         TEXT NOT NULL,
  agent_type         TEXT,                -- e.g. "agent-flow:Loid"
  description        TEXT,
  parent_tool_use_id TEXT,
  spawned_at         TEXT,
  stopped_at         TEXT,
  input_prompt       TEXT,
  accepted_output    TEXT,
  model              TEXT
);

CREATE TABLE IF NOT EXISTS events (
  event_id          TEXT PRIMARY KEY,     -- message uuid or synthetic
  session_id        TEXT NOT NULL,
  parent_uuid       TEXT,
  agent_id          TEXT,
  agent_type        TEXT,                 -- denormalized for fast GROUP BY
  role              TEXT,                 -- user|assistant|system
  tool_use_id       TEXT,
  tool_name         TEXT,
  tool_input_json   TEXT,
  tool_result_json  TEXT,
  decision          TEXT,                 -- approve|block|deny|null (from Stop hooks)
  thinking_text     TEXT,                 -- concatenated thinking blocks for this event
  input_tokens      INTEGER,
  output_tokens     INTEGER,
  cache_read_tokens INTEGER,
  cache_creation_tokens INTEGER,
  model             TEXT,
  git_branch        TEXT,
  cwd               TEXT,
  is_sidechain      INTEGER,              -- 1 if subagent event
  ts                TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_session    ON events(session_id, ts);
CREATE INDEX IF NOT EXISTS idx_events_agent      ON events(agent_type, ts);
CREATE INDEX IF NOT EXISTS idx_events_tool       ON events(tool_name);
CREATE INDEX IF NOT EXISTS idx_events_sidechain  ON events(is_sidechain);

-- Iteration log mirrored from .claude/orchestration.local.md
CREATE TABLE IF NOT EXISTS iterations (
  session_id  TEXT,
  phase       TEXT,
  iteration_n INTEGER,
  agent       TEXT,
  gate_result TEXT,
  message     TEXT,
  ts          TEXT
);

-- Manual labels for subagent recall evaluation (M5)
CREATE TABLE IF NOT EXISTS labels (
  label_id     TEXT PRIMARY KEY,
  session_id   TEXT NOT NULL,
  event_id     TEXT,                -- optional: specific event
  agent_id     TEXT,                -- subagent this labels
  agent_type   TEXT,
  verdict      TEXT NOT NULL,       -- 'correct' | 'missed' | 'extra' | 'wrong'
  note         TEXT,
  ts           TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_labels_session ON labels(session_id);
CREATE INDEX IF NOT EXISTS idx_labels_verdict ON labels(verdict);

DROP VIEW IF EXISTS v_tool_usage_by_agent;
CREATE VIEW v_tool_usage_by_agent AS
SELECT COALESCE(agent_type, '<orchestrator>') AS agent_type,
       tool_name,
       COUNT(*) AS n
FROM events WHERE tool_name IS NOT NULL
GROUP BY agent_type, tool_name
ORDER BY agent_type, n DESC;

DROP VIEW IF EXISTS v_skill_invocations;
CREATE VIEW v_skill_invocations AS
SELECT COALESCE(agent_type, '<orchestrator>') AS agent_type,
       tool_name,
       COUNT(*) AS n
FROM events WHERE tool_name LIKE 'mcp__%' OR tool_name = 'Skill'
GROUP BY agent_type, tool_name
ORDER BY agent_type, n DESC;

DROP VIEW IF EXISTS v_thinking_by_agent;
CREATE VIEW v_thinking_by_agent AS
SELECT COALESCE(agent_type, '<orchestrator>') AS agent_type,
       COUNT(*) AS thinking_events,
       SUM(LENGTH(thinking_text)) AS total_chars,
       AVG(LENGTH(thinking_text)) AS avg_chars
FROM events WHERE thinking_text IS NOT NULL AND thinking_text != ''
GROUP BY agent_type;

DROP VIEW IF EXISTS v_tokens_by_agent;
CREATE VIEW v_tokens_by_agent AS
SELECT COALESCE(agent_type, '<orchestrator>') AS agent_type,
       model,
       COUNT(*) AS events,
       SUM(input_tokens) AS input,
       SUM(output_tokens) AS output,
       SUM(cache_read_tokens) AS cache_read,
       SUM(cache_creation_tokens) AS cache_creation
FROM events WHERE role = 'assistant'
GROUP BY agent_type, model;

DROP VIEW IF EXISTS v_subagent_dispatch;
CREATE VIEW v_subagent_dispatch AS
SELECT session_id,
       json_extract(tool_input_json, '$.subagent_type') AS subagent_type,
       COUNT(*) AS dispatches
FROM events
WHERE tool_name IN ('Agent','Task')
GROUP BY session_id, subagent_type
ORDER BY session_id, dispatches DESC;

DROP VIEW IF EXISTS v_iteration_rate;
CREATE VIEW v_iteration_rate AS
SELECT subagent_type,
       SUM(dispatches) AS total_dispatches,
       COUNT(DISTINCT session_id) AS sessions,
       ROUND(1.0 * SUM(dispatches) / COUNT(DISTINCT session_id), 2) AS dispatches_per_session
FROM v_subagent_dispatch
WHERE subagent_type IS NOT NULL
GROUP BY subagent_type;

DROP VIEW IF EXISTS v_rejection_rate;
CREATE VIEW v_rejection_rate AS
SELECT COALESCE(agent_type,'<orchestrator>') AS agent_type,
       SUM(CASE WHEN decision='block' THEN 1 ELSE 0 END) AS blocks,
       SUM(CASE WHEN decision='approve' THEN 1 ELSE 0 END) AS approves,
       SUM(CASE WHEN decision='deny' THEN 1 ELSE 0 END) AS denies,
       COUNT(decision) AS decided
FROM events WHERE decision IS NOT NULL
GROUP BY agent_type;

DROP VIEW IF EXISTS v_session_summary;
CREATE VIEW v_session_summary AS
SELECT s.session_id, s.started_at, s.ended_at, s.git_branch,
       s.event_count,
       (SELECT COUNT(DISTINCT agent_id) FROM subagents WHERE session_id=s.session_id) AS subagents,
       (SELECT COUNT(*) FROM events WHERE session_id=s.session_id AND tool_name IN ('Agent','Task')) AS agent_dispatches
FROM sessions s;

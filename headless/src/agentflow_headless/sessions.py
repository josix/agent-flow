"""Persistent session records for headless runs.

A headless session binds together the caller-facing ``session_id``, the
workspace (where agent-flow's own orchestration state lives), and the
Claude Agent SDK session ID needed to resume the underlying conversation.
Records are JSON files under ``<workspace>/.claude/headless-sessions/`` —
next to the orchestration state file, so wiping a workspace wipes both.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SESSIONS_DIR_RELPATH = Path(".claude") / "headless-sessions"


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class SessionNotFoundError(KeyError):
    pass


@dataclass
class SessionRecord:
    session_id: str
    workspace: str
    plugin_dir: str
    task: str
    policy: str
    permission_mode: str
    sdk_session_id: str | None = None
    status: str = "created"  # created | running | needs_input | completed | failed
    pending_question: str | None = None
    pending_question_payload: dict[str, Any] | None = None
    created_at: str = field(default_factory=_utcnow)
    updated_at: str = field(default_factory=_utcnow)

    @classmethod
    def create(
        cls,
        *,
        workspace: Path,
        plugin_dir: Path,
        task: str,
        policy: str,
        permission_mode: str,
    ) -> "SessionRecord":
        return cls(
            session_id=uuid.uuid4().hex[:12],
            workspace=str(Path(workspace).resolve()),
            plugin_dir=str(Path(plugin_dir).resolve()),
            task=task,
            policy=policy,
            permission_mode=permission_mode,
        )

    def touch(self) -> None:
        self.updated_at = _utcnow()


def _record_path(workspace: Path, session_id: str) -> Path:
    return Path(workspace) / SESSIONS_DIR_RELPATH / f"{session_id}.json"


def save(record: SessionRecord) -> Path:
    record.touch()
    path = _record_path(Path(record.workspace), record.session_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(asdict(record), indent=2, ensure_ascii=False), encoding="utf-8")
    tmp.replace(path)
    return path


def load(workspace: Path, session_id: str) -> SessionRecord:
    path = _record_path(Path(workspace), session_id)
    if not path.is_file():
        raise SessionNotFoundError(f"no headless session {session_id!r} under {workspace}")
    data = json.loads(path.read_text(encoding="utf-8"))
    known = {f.name for f in SessionRecord.__dataclass_fields__.values()}  # type: ignore[attr-defined]
    return SessionRecord(**{k: v for k, v in data.items() if k in known})


def list_sessions(workspace: Path) -> list[SessionRecord]:
    directory = Path(workspace) / SESSIONS_DIR_RELPATH
    if not directory.is_dir():
        return []
    records = []
    for path in sorted(directory.glob("*.json")):
        try:
            records.append(load(workspace, path.stem))
        except (json.JSONDecodeError, TypeError):
            continue
    return records

import pytest

from agentflow_headless import sessions


def make_record(tmp_path):
    return sessions.SessionRecord.create(
        workspace=tmp_path,
        plugin_dir=tmp_path / "plugin",
        task="Add feature",
        policy="escalate",
        permission_mode="acceptEdits",
    )


def test_round_trip(tmp_path):
    record = make_record(tmp_path)
    record.sdk_session_id = "sdk-123"
    record.status = "needs_input"
    record.pending_question = "Which auth scheme?"
    sessions.save(record)

    loaded = sessions.load(tmp_path, record.session_id)
    assert loaded.session_id == record.session_id
    assert loaded.sdk_session_id == "sdk-123"
    assert loaded.status == "needs_input"
    assert loaded.pending_question == "Which auth scheme?"
    assert loaded.task == "Add feature"


def test_load_missing_session_raises(tmp_path):
    with pytest.raises(sessions.SessionNotFoundError):
        sessions.load(tmp_path, "nope")


def test_list_sessions(tmp_path):
    assert sessions.list_sessions(tmp_path) == []
    a = make_record(tmp_path)
    b = make_record(tmp_path)
    sessions.save(a)
    sessions.save(b)
    ids = {r.session_id for r in sessions.list_sessions(tmp_path)}
    assert ids == {a.session_id, b.session_id}


def test_save_updates_timestamp(tmp_path):
    record = make_record(tmp_path)
    original = record.updated_at
    record.updated_at = "1970-01-01T00:00:00Z"
    sessions.save(record)
    assert sessions.load(tmp_path, record.session_id).updated_at >= original

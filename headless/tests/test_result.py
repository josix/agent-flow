import json

import pytest

from agentflow_headless.result import MAX_SUMMARY_CHARS, DelegatedAgentResult, ResultStatus


def test_json_shape():
    result = DelegatedAgentResult(
        status=ResultStatus.NEEDS_INPUT,
        summary="paused",
        session_id="abc123",
        question="Which auth scheme?",
    )
    data = json.loads(result.to_json())
    assert data["status"] == "needs_input"
    assert data["session_id"] == "abc123"
    assert data["question"] == "Which auth scheme?"
    assert data["error"] is None
    assert data["approval_request"] is None


def test_invalid_status_rejected():
    with pytest.raises(ValueError, match="invalid status"):
        DelegatedAgentResult(status="done", summary="x")


def test_summary_is_bounded():
    result = DelegatedAgentResult(status=ResultStatus.COMPLETED, summary="x" * 10_000)
    assert len(result.summary) == MAX_SUMMARY_CHARS
    assert result.summary.endswith("...")


@pytest.mark.parametrize(
    ("status", "code"),
    [
        (ResultStatus.COMPLETED, 0),
        (ResultStatus.FAILED, 1),
        (ResultStatus.NEEDS_INPUT, 10),
        (ResultStatus.NEEDS_APPROVAL, 11),
    ],
)
def test_exit_codes(status, code):
    assert DelegatedAgentResult(status=status, summary="s").exit_code == code

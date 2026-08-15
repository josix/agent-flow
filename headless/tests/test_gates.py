import pytest

from agentflow_headless.gates import (
    AUTO_DENY_MESSAGE,
    POLICY_AUTO,
    POLICY_ESCALATE,
    evaluate_tool_use,
    format_question,
)

QUESTION_INPUT = {
    "questions": [
        {
            "question": "Should API-key authentication remain supported?",
            "header": "Auth",
            "multiSelect": False,
            "options": [
                {"label": "Keep it", "description": "Existing clients depend on it"},
                {"label": "Remove it"},
            ],
        }
    ]
}


def test_non_gate_tools_are_allowed():
    for tool in ("Bash", "Write", "Task", "Read"):
        assert evaluate_tool_use(tool, {"anything": 1}, POLICY_ESCALATE).kind == "allow"


def test_escalate_policy_captures_question():
    decision = evaluate_tool_use("AskUserQuestion", QUESTION_INPUT, POLICY_ESCALATE)
    assert decision.kind == "escalate"
    assert "API-key authentication" in decision.question
    assert "- Keep it: Existing clients depend on it" in decision.question
    assert "- Remove it" in decision.question
    assert decision.question_payload == QUESTION_INPUT
    assert "escalated" in decision.deny_message


def test_auto_policy_denies_with_default_instruction():
    decision = evaluate_tool_use("AskUserQuestion", QUESTION_INPUT, POLICY_AUTO)
    assert decision.kind == "deny"
    assert decision.deny_message == AUTO_DENY_MESSAGE
    assert decision.question == ""


def test_unknown_policy_raises():
    with pytest.raises(ValueError, match="unknown gate policy"):
        evaluate_tool_use("AskUserQuestion", QUESTION_INPUT, "yolo")


def test_format_question_handles_malformed_input():
    assert "unstructured" in format_question({})
    assert "unstructured" in format_question({"questions": [{"no": "question"}]})


def test_format_question_joins_multiple_questions():
    rendered = format_question(
        {"questions": [{"question": "First?"}, {"question": "Second?"}]}
    )
    assert "First?" in rendered
    assert "Second?" in rendered

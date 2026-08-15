from pathlib import Path

import pytest

from agentflow_headless.result import ResultStatus
from agentflow_headless.state import (
    COMPLETION_SENTINEL,
    OrchestrationState,
    derive_outcome,
    parse_frontmatter,
)

FRONTMATTER_TEMPLATE = """---
active: {active}
current_phase: "{phase}"
iteration: 2
max_iterations: 10
codex_divergence_rounds: 0
started_at: "2026-08-15T10:00:00Z"
task: "Add \\"quoted\\" feature"
# task_complexity = task-classification tier
task_complexity: "{complexity}"
report_requested: {report_requested}
intent:
  goal: "ship it"
  description: ""
deep_dive:
  available: false
  using: false
gates:
  exploration:
    status: "passed"
    timestamp: "2026-08-15T10:01:00Z"
  planning:
    status: "passed"
  implementation:
    status: "{impl_status}"
  review:
    status: "{review_status}"
  verification:
    status: "{verification_status}"
---

## Orchestration Log
"""


def write_state(
    tmp_path: Path,
    *,
    active="false",
    phase="complete",
    complexity="implementation",
    report_requested="false",
    impl_status="passed",
    review_status="passed",
    verification_status="passed",
) -> Path:
    state_dir = tmp_path / ".claude"
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "orchestration.local.md").write_text(
        FRONTMATTER_TEMPLATE.format(
            active=active,
            phase=phase,
            complexity=complexity,
            report_requested=report_requested,
            impl_status=impl_status,
            review_status=review_status,
            verification_status=verification_status,
        ),
        encoding="utf-8",
    )
    return tmp_path


def test_parse_frontmatter_types_and_nesting(tmp_path):
    write_state(tmp_path)
    state = OrchestrationState.load(tmp_path)
    assert state.exists
    assert state.active is False
    assert state.current_phase == "complete"
    assert state.iteration == 2
    assert state.max_iterations == 10
    assert state.task == 'Add "quoted" feature'
    assert state.gate_status("verification") == "passed"
    assert state.gate_status("exploration") == "passed"
    assert state.raw["intent"]["goal"] == "ship it"


def test_parse_frontmatter_no_frontmatter():
    assert parse_frontmatter("no frontmatter here") == {}


def test_missing_state_file_is_failed(tmp_path):
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state)
    assert outcome.status == ResultStatus.FAILED
    assert not outcome.resumable


def test_verified_run_is_completed(tmp_path):
    write_state(tmp_path)
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state, final_text=f"done\n{COMPLETION_SENTINEL}")
    assert outcome.status == ResultStatus.COMPLETED
    assert outcome.detail["completion_sentinel_seen"] is True


def test_pending_question_wins_over_everything(tmp_path):
    write_state(tmp_path, active="true", phase="planning", verification_status="pending")
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state, pending_question=True, run_error="ignored")
    assert outcome.status == ResultStatus.NEEDS_INPUT
    assert outcome.resumable


def test_inactive_without_verification_is_failed(tmp_path):
    write_state(tmp_path, verification_status="failed")
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state)
    assert outcome.status == ResultStatus.FAILED
    assert "verification=failed" in outcome.reason


@pytest.mark.parametrize(
    ("complexity", "report_requested"),
    [("research", "false"), ("exploratory", "false"), ("implementation", "true")],
)
def test_research_short_circuit_is_completed(tmp_path, complexity, report_requested):
    write_state(
        tmp_path,
        complexity=complexity,
        report_requested=report_requested,
        impl_status="pending",
        review_status="pending",
        verification_status="pending",
    )
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state)
    assert outcome.status == ResultStatus.COMPLETED


def test_interrupted_active_run_is_failed_but_resumable(tmp_path):
    write_state(tmp_path, active="true", phase="implementation", verification_status="pending")
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state)
    assert outcome.status == ResultStatus.FAILED
    assert outcome.resumable
    assert "phase=implementation" in outcome.reason


def test_run_error_beats_state_verdict(tmp_path):
    write_state(tmp_path)
    state = OrchestrationState.load(tmp_path)
    outcome = derive_outcome(state, run_error="time budget of 60s exceeded")
    assert outcome.status == ResultStatus.FAILED
    assert outcome.resumable
    assert "time budget" in outcome.reason

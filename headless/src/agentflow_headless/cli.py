"""Command-line entry point for the headless driver.

Every command prints one DelegatedAgentResult JSON object to stdout, so a
caller (an Airflow toolset, a CI job, a script) can drive agent-flow with
subprocess + JSON alone.

Exit codes: 0 completed, 1 failed, 10 needs_input, 11 needs_approval,
2 usage error.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from agentflow_headless import driver, gates
from agentflow_headless.sessions import SessionNotFoundError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="agentflow-headless",
        description="Run agent-flow orchestrations non-interactively with a start/resume lifecycle.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    start = sub.add_parser("start", help="Start a new orchestration session")
    start.add_argument("--task", required=True, help="Task description to orchestrate")
    start.add_argument("--workspace", required=True, type=Path, help="Repository/workspace directory the orchestration runs in")
    start.add_argument("--plugin-dir", required=True, type=Path, help="Path to the agent-flow plugin checkout")
    start.add_argument(
        "--policy",
        choices=gates.POLICIES,
        default=gates.POLICY_ESCALATE,
        help="How to handle AskUserQuestion gates: escalate (pause and return needs_input) or auto (proceed with documented defaults)",
    )
    start.add_argument("--permission-mode", default=driver.DEFAULT_PERMISSION_MODE, help="Claude Agent SDK permission mode (default: %(default)s)")
    start.add_argument("--max-turns", type=int, default=driver.DEFAULT_MAX_TURNS)
    start.add_argument("--timeout", type=float, default=None, metavar="SECONDS", help="Wall-clock budget; on expiry the run stops resumable")
    start.add_argument("--model", default=None, help="Model override for the orchestrator session")

    resume = sub.add_parser("resume", help="Resume a session, answering its escalated question")
    resume.add_argument("--session-id", required=True)
    resume.add_argument("--workspace", required=True, type=Path)
    resume.add_argument("--response", required=True, help="Answer to the escalated question (or steering instruction)")
    resume.add_argument("--max-turns", type=int, default=driver.DEFAULT_MAX_TURNS)
    resume.add_argument("--timeout", type=float, default=None, metavar="SECONDS")
    resume.add_argument("--model", default=None)

    status = sub.add_parser("status", help="Report a session's state from disk without running anything")
    status.add_argument("--session-id", required=True)
    status.add_argument("--workspace", required=True, type=Path)

    for p in (start, resume, status):
        p.add_argument("--pretty", action="store_true", help="Pretty-print the result JSON")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "start":
            result = driver.start(
                args.task,
                workspace=args.workspace,
                plugin_dir=args.plugin_dir,
                policy=args.policy,
                permission_mode=args.permission_mode,
                max_turns=args.max_turns,
                timeout_seconds=args.timeout,
                model=args.model,
            )
        elif args.command == "resume":
            result = driver.resume(
                args.session_id,
                args.response,
                workspace=args.workspace,
                max_turns=args.max_turns,
                timeout_seconds=args.timeout,
                model=args.model,
            )
        else:
            result = driver.status(args.session_id, workspace=args.workspace)
    except (ValueError, SessionNotFoundError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(result.to_json(indent=2 if args.pretty else None))
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())

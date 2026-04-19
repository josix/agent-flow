"""MLflow exporter — requires `pip install mlflow`. Raises ExporterUnavailable otherwise."""
from __future__ import annotations

import json
import pathlib
import tempfile
from typing import Iterable

from .base import Exporter, ExporterUnavailable


class MlflowExporter(Exporter):
    name = "mlflow"

    def export(self, events: Iterable[dict]) -> int:
        try:
            import mlflow  # type: ignore[import]
        except ImportError:
            raise ExporterUnavailable(
                "mlflow not installed — `pip install mlflow` or `uv pip install mlflow` to enable"
            )

        tracking_uri = self.config.get("tracking_uri", "file:.claude/observability/mlflow")
        experiment_name = self.config.get("experiment", "agent-flow")

        mlflow.set_tracking_uri(tracking_uri)
        mlflow.set_experiment(experiment_name)

        # Group events by session_id
        by_session: dict[str, list[dict]] = {}
        for ev in events:
            sid = ev.get("session_id", "unknown")
            by_session.setdefault(sid, []).append(ev)

        total = 0
        for session_id, session_events in by_session.items():
            session_events_sorted = sorted(session_events, key=lambda e: e.get("ts") or "")
            total += len(session_events_sorted)

            # Aggregate metrics
            tool_counts: dict[str, int] = {}
            prompt_tokens = 0
            completion_tokens = 0
            for ev in session_events_sorted:
                tn = ev.get("tool_name")
                if tn:
                    tool_counts[tn] = tool_counts.get(tn, 0) + 1
                prompt_tokens += ev.get("input_tokens") or 0
                completion_tokens += ev.get("output_tokens") or 0

            with mlflow.start_run(run_name=session_id):
                mlflow.log_metric("llm.token_count.prompt", prompt_tokens)
                mlflow.log_metric("llm.token_count.completion", completion_tokens)
                mlflow.log_metric("event_count", len(session_events_sorted))
                for tool, cnt in tool_counts.items():
                    safe_name = tool.replace(".", "_").replace("/", "_")
                    mlflow.log_metric(f"tool.{safe_name}", cnt)

                # Write event stream as artifact
                with tempfile.NamedTemporaryFile(
                    mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
                ) as tf:
                    for ev in session_events_sorted:
                        tf.write(json.dumps(ev) + "\n")
                    tmp_path = tf.name

                try:
                    mlflow.log_artifact(tmp_path, artifact_path="events")
                finally:
                    pathlib.Path(tmp_path).unlink(missing_ok=True)

        return total

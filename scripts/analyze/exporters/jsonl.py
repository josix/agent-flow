"""JSONL exporter — stdlib only, one line per event ordered by ts."""
from __future__ import annotations

import json
import pathlib
from typing import Iterable

from .base import Exporter


class JsonlExporter(Exporter):
    name = "jsonl"

    def export(self, events: Iterable[dict]) -> int:
        path_str = self.config.get("path", ".claude/observability/export.jsonl")
        out_path = pathlib.Path(path_str)
        out_path.parent.mkdir(parents=True, exist_ok=True)

        rows = sorted(events, key=lambda e: e.get("ts") or "")
        with open(out_path, "w", encoding="utf-8") as fh:
            for row in rows:
                fh.write(json.dumps(row) + "\n")

        return len(rows)

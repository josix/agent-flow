"""Exporter registry. load_exporters(config) -> list[Exporter]."""
from __future__ import annotations

import sys

from .base import Exporter, ExporterUnavailable
from .jsonl import JsonlExporter
from .mlflow import MlflowExporter

_REGISTRY: dict[str, type[Exporter]] = {
    "jsonl": JsonlExporter,
    "mlflow": MlflowExporter,
}


def load_exporters(config: dict) -> list[Exporter]:
    """Instantiate exporters listed in config["exporters"]."""
    names = config.get("exporters", [])
    result: list[Exporter] = []
    for name in names:
        cls = _REGISTRY.get(name)
        if cls is None:
            print(f"[warn] unknown exporter '{name}' — available: {sorted(_REGISTRY)}", file=sys.stderr)
            continue
        exporter_config = config.get(name, {})
        result.append(cls(exporter_config))
    return result


__all__ = ["Exporter", "ExporterUnavailable", "load_exporters"]

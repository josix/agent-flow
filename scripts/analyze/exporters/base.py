"""Base exporter interface."""
from __future__ import annotations

from typing import Iterable


class ExporterUnavailable(Exception):
    """Raised when an exporter's dependencies are not installed."""


class Exporter:
    name: str = ""

    def __init__(self, config: dict) -> None:
        self.config = config

    def export(self, events: Iterable[dict]) -> int:
        """Export events. Return count exported. Raise ExporterUnavailable if deps missing."""
        raise NotImplementedError

#!/usr/bin/env bash
# log-event-bench.sh — micro-benchmark for log-event.py
# Sends 100 synthetic hook payloads and reports p50/p95 latency in ms.
# Dev-only; not wired into any hook.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -x "$PLUGIN_DIR/.venv/bin/python" ]]; then
  PY="$PLUGIN_DIR/.venv/bin/python"
else
  PY="$(command -v python3 || command -v python || true)"
fi

if [[ -z "$PY" ]]; then
  echo "ERROR: python3 not found" >&2
  exit 1
fi

SAMPLE_PAYLOAD='{"session_id":"bench-session","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"cwd":"/tmp"}'
N=100

echo "Running $N invocations of log-event.py ..."

# Run all iterations inside a single Python process for accurate timing
"$PY" - "$PLUGIN_DIR" "$SAMPLE_PAYLOAD" "$N" <<'PYEOF'
import subprocess, sys, time, statistics

plugin_dir = sys.argv[1]
payload = sys.argv[2]
n = int(sys.argv[3])
py = sys.executable
script = plugin_dir + "/hooks/scripts/log-event.py"

times = []
for _ in range(n):
    t0 = time.perf_counter()
    result = subprocess.run(
        [py, "-S", script, "postToolUse"],
        input=payload,
        capture_output=True,
        text=True,
    )
    t1 = time.perf_counter()
    times.append((t1 - t0) * 1000)

times_sorted = sorted(times)
nn = len(times_sorted)
p50 = times_sorted[int(nn * 0.50)]
p95 = times_sorted[int(nn * 0.95)]
mean = statistics.mean(times)
print(f"Benchmark results ({nn} runs):")
print(f"  p50:  {p50:.1f} ms")
print(f"  p95:  {p95:.1f} ms")
print(f"  mean: {mean:.1f} ms")
print(f"  min:  {times_sorted[0]:.1f} ms")
print(f"  max:  {times_sorted[-1]:.1f} ms")
if p95 >= 20:
    print(f"  WARNING: p95 ({p95:.1f} ms) >= 20 ms threshold!")
else:
    print(f"  OK: p95 < 20 ms threshold")
PYEOF

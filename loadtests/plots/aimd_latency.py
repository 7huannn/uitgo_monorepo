"""
Plot p95 latency vs RPS for UIT-Go load tests.

Behaviour:
- If there are k6 summaries in `loadtests/results/run_*.json`, the script
  will load them and plot the real p95 vs RPS curve.
- If no data is found, it falls back to the synthetic AIMD-like curve
  used in the report.

Usage:
  python aimd_latency.py

Output:
  - loadtests/plots/rps_p95.png (real data if available, otherwise synthetic)
"""

import json
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def load_k6_results(results_dir: Path):
    """Load p95 latency from k6 summary json files named run_<R>.json."""
    points = []
    for path in sorted(results_dir.glob("run_*.json")):
        m = re.search(r"run_(\d+)", path.name)
        if not m:
            continue
        rps = int(m.group(1))
        with path.open() as f:
            data = json.load(f)
        try:
            p95 = data["metrics"]["http_req_duration"]["trend"]["p(95)"]
        except KeyError:
            continue
        points.append((rps, p95))
    points.sort()
    return points


def generate_synthetic_data():
    """Create a synthetic AIMD-like curve for fallback."""
    rps = np.linspace(0, 200, 201)

    latency = []
    for x in rps:
        if x <= 60:
            # Almost flat: 80–150 ms
            base = 80 + (x / 60) * 70
        elif x <= 120:
            # Non-linear: queueing effects
            # Grows from ~150 ms to ~900 ms
            y = (x - 60) / 60.0
            base = 150 + (y ** 2.2) * 750
        else:
            # Back-pressure: latency grows steeply, but we clamp it
            y = (x - 120) / 80.0
            base = 900 + (y ** 2.0) * 1100

        # Add a small jitter to avoid a perfectly smooth line
        jitter = np.random.normal(0, 20)
        latency.append(max(50.0, base + jitter))

    return list(zip(rps.tolist(), latency))


def main():
    base_dir = Path(__file__).resolve().parent
    results_dir = base_dir.parent / "results"

    points = load_k6_results(results_dir)
    used_real_data = bool(points)

    if not points:
        points = generate_synthetic_data()

    x, y = zip(*points)

    plt.style.use("seaborn-v0_8")
    fig, ax = plt.subplots(figsize=(8, 5))

    label = "p95 latency (k6)" if used_real_data else "p95 latency (synthetic)"
    ax.plot(x, y, marker="o" if used_real_data else None, label=label, color="#3366CC")

    if not used_real_data:
        # Only show synthetic annotations when no real data is present
        ax.axvline(60, color="#999999", linestyle="--", linewidth=1)
        ax.axvline(120, color="#999999", linestyle="--", linewidth=1)
        ax.text(30, 1000, "Region A:\nhealthy", ha="center", va="center", fontsize=8)
        ax.text(90, 1300, "Region B:\nqueueing", ha="center", va="center", fontsize=8)
        ax.text(160, 1700, "Region C:\nback-pressure", ha="center", va="center", fontsize=8)

    ax.set_xlabel("Requests per second (RPS)")
    ax.set_ylabel("p95 latency (ms)")
    ax.set_title("p95 latency vs RPS for UIT-Go")
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=0.3)
    ax.legend()

    out_path = base_dir / "rps_p95.png"
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"Saved plot to: {out_path} (source: {'k6 results' if used_real_data else 'synthetic'})")


if __name__ == "__main__":
    # Ensure a non-interactive backend for headless environments
    import matplotlib

    matplotlib.use("Agg")
    main()

"""
Plot p95 latency vs RPS for UIT-Go load tests.

Behaviour:
- Prefer real p95 data from k6 summaries in `loadtests/results/*run_*.json`
  (supports env prefixes: local_run_XX.json, aws_run_XX.json).
- Fall back to the synthetic AIMD-like curve only when no real data exists.

Usage:
  python aimd_latency.py

Output:
  - loadtests/plots/rps_p95.png (local vs aws series if present, otherwise synthetic)
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
import numpy as np

# Metric keys
METRIC_KEY_P95 = "p(95)"


def parse_env_and_rps(path: Path) -> Tuple[str, int]:
    m = re.search(r"(?:(local|aws)[_-])?run_(\d+)", path.stem, flags=re.IGNORECASE)
    env = (m.group(1).lower() if m and m.group(1) else "unknown")
    rps = int(m.group(2)) if m else -1
    return env, rps


def extract_p95(data: Dict) -> Optional[float]:
    metrics = data.get("metrics", {})
    duration = metrics.get("http_req_duration", {}) or {}
    trend = duration.get("trend") if isinstance(duration, dict) else {}

    if isinstance(duration, dict) and METRIC_KEY_P95 in duration:
        return duration[METRIC_KEY_P95]
    if isinstance(trend, dict):
        return trend.get(METRIC_KEY_P95)
    return None


def load_k6_results(results_dir: Path) -> Dict[str, List[Tuple[int, float]]]:
    """Load p95 latency per env from k6 summary json files named *run_<R>.json."""
    series: Dict[str, List[Tuple[int, float]]] = {}
    for path in sorted(results_dir.glob("*run_*.json")):
        env, rps = parse_env_and_rps(path)
        if rps < 0:
            continue
        with path.open() as f:
            data = json.load(f)
        p95 = extract_p95(data)
        if p95 is None:
            continue
        series.setdefault(env, []).append((rps, p95))
    for env in series:
        series[env].sort()
    return {k: v for k, v in series.items() if v}


def generate_synthetic_data():
    """Create a deterministic synthetic AIMD-like curve for fallback."""
    rps = np.linspace(0, 200, 201)
    rng = np.random.default_rng(seed=0)

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
        jitter = rng.normal(0, 20)
        latency.append(max(50.0, base + jitter))

    return list(zip(rps.tolist(), latency))


def main():
    base_dir = Path(__file__).resolve().parent
    results_dir = base_dir.parent / "results"

    plt.style.use("seaborn-v0_8")
    fig, ax = plt.subplots(figsize=(8, 5))

    series = load_k6_results(results_dir)
    used_real_data = bool(series)

    if used_real_data:
        colors = {"local": "#3366CC", "aws": "#FF7F0E", "unknown": "#777777"}
        markers = {"local": "o", "aws": "s", "unknown": "^"}
        for env, points in sorted(series.items()):
            x, y = zip(*points)
            ax.plot(
                x,
                y,
                marker=markers.get(env, "o"),
                linestyle="-",
                label=f"{env.upper()} p95 latency",
                color=colors.get(env, None),
            )
    else:
        x, y = zip(*generate_synthetic_data())
        ax.plot(x, y, label="p95 latency (synthetic)", color="#3366CC")
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

"""
Aggregate k6 summary exports into CSV and Markdown tables.

Inputs: loadtests/results/*run_*.json
Outputs:
  - loadtests/report/summary.csv
  - loadtests/report/summary.md
"""

import csv
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple

RESULTS_DIR = Path(__file__).resolve().parents[1] / "results"
REPORT_DIR = Path(__file__).resolve().parents[1] / "report"


def parse_env_and_rps(path: Path) -> Tuple[str, int]:
    """
    Derive environment and RPS from filename conventions:
    - local_run_20.json -> (local, 20)
    - aws_run_40.json   -> (aws, 40)
    - run_60.json       -> (unknown, 60)
    """
    stem = path.stem
    m = re.search(r"(?:(local|aws)[_-])?run_(\d+)", stem, flags=re.IGNORECASE)
    env = (m.group(1).lower() if m and m.group(1) else "unknown")
    rps = int(m.group(2)) if m else -1
    return env, rps


def extract_metrics(data: Dict) -> Tuple[float, float, float]:
    metrics = data.get("metrics", {})
    duration = metrics.get("http_req_duration", {}) or {}
    trend = duration.get("trend") if isinstance(duration, dict) else {}

    p95 = None
    if isinstance(duration, dict):
        p95 = duration.get("p(95)")
    if p95 is None and isinstance(trend, dict):
        p95 = trend.get("p(95)")

    http_reqs = metrics.get("http_reqs", {}) or {}
    achieved_rps = http_reqs.get("rate")

    http_failed = metrics.get("http_req_failed", {}) or {}
    error_rate = http_failed.get("value")

    return p95, achieved_rps, error_rate


def load_points() -> List[Dict]:
    points: List[Dict] = []
    for path in sorted(RESULTS_DIR.glob("*run_*.json")):
        env, rps = parse_env_and_rps(path)
        if rps < 0:
            continue
        with path.open() as f:
            data = json.load(f)
        p95, achieved_rps, error_rate = extract_metrics(data)
        points.append(
            {
                "environment": env,
                "rps": rps,
                "p95_ms": p95,
                "achieved_rps": achieved_rps,
                "error_rate": error_rate,
                "source": str(path.relative_to(Path.cwd()) if path.is_absolute() else path),
            }
        )
    points.sort(key=lambda x: (x["environment"], x["rps"]))
    return points


def write_csv(rows: List[Dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["environment", "rps", "p95_ms", "achieved_rps", "error_rate", "source"]
        )
        writer.writeheader()
        writer.writerows(rows)


def write_md(rows: List[Dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    headers = ["environment", "rps", "p95_ms", "achieved_rps", "error_rate", "source"]
    lines = ["|" + "|".join(h.replace("_", " ") for h in headers) + "|", "|" + "|".join(["---"] * len(headers)) + "|"]
    for row in rows:
        lines.append(
            "|"
            + "|".join(
                [
                    str(row.get("environment", "")),
                    str(row.get("rps", "")),
                    f"{row.get('p95_ms', '')}",
                    f"{row.get('achieved_rps', '')}",
                    f"{row.get('error_rate', '')}",
                    str(row.get("source", "")),
                ]
            )
            + "|"
        )
    path.write_text("\n".join(lines))


def main():
    rows = load_points()
    write_csv(rows, REPORT_DIR / "summary.csv")
    write_md(rows, REPORT_DIR / "summary.md")
    print(f"Wrote {len(rows)} rows to {REPORT_DIR / 'summary.csv'} and {REPORT_DIR / 'summary.md'}")


if __name__ == "__main__":
    main()

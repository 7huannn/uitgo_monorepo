#!/usr/bin/env python3
"""
Generate comprehensive comparison report between Local and AWS load tests.

Inputs: loadtests/results/*.json
Outputs:
  - loadtests/report/comparison.md (Markdown report)
  - loadtests/report/comparison.html (HTML report)
  - loadtests/report/comparison_charts.png (Visualization)
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass
from datetime import datetime

try:
    import matplotlib.pyplot as plt
    import numpy as np
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not available. Charts will not be generated.")

RESULTS_DIR = Path(__file__).resolve().parents[1] / "results"
REPORT_DIR = Path(__file__).resolve().parents[1] / "report"

# Common labels
LABEL_TARGET_RPS = "Target RPS"


@dataclass
class TestResult:
    environment: str
    test_type: str
    rps_target: int
    rps_achieved: float
    p50_latency: float
    p95_latency: float
    p99_latency: float
    avg_latency: float
    max_latency: float
    error_rate: float
    total_requests: int
    duration: float


def parse_filename(path: Path) -> Tuple[str, str, int]:
    """
    Parse environment, test type, and RPS from filename.
    Examples:
    - local_run_20.json -> (local, trip_matching, 20)
    - aws_home_meta.json -> (aws, home_meta, 0)
    - local_search_only.json -> (local, search, 0)
    """
    stem = path.stem
    
    # Determine environment
    if stem.startswith('local_'):
        env = 'local'
        remainder = stem[6:]
    elif stem.startswith('aws_'):
        env = 'aws'
        remainder = stem[4:]
    else:
        env = 'unknown'
        remainder = stem
    
    # Determine test type and RPS
    if 'home_meta' in remainder:
        test_type = 'home_meta'
        rps = 0
    elif 'search_only' in remainder:
        test_type = 'search'
        rps = 0
    elif match := re.search(r'run_(\d+)', remainder):
        test_type = 'trip_matching'
        rps = int(match.group(1))
    else:
        test_type = 'unknown'
        rps = 0
    
    return env, test_type, rps


def extract_metrics(data: Dict) -> Dict:
    """Extract relevant metrics from k6 summary export."""
    metrics = data.get("metrics", {})
    
    # HTTP request duration
    duration = metrics.get("http_req_duration", {})
    values = duration.get("values", {}) if isinstance(duration, dict) else {}
    
    # HTTP requests count and rate
    http_reqs = metrics.get("http_reqs", {})
    
    # Error rate
    http_failed = metrics.get("http_req_failed", {})
    
    # Test duration
    iteration_duration = metrics.get("iteration_duration", {})
    
    return {
        'p50': values.get('p(50)', duration.get('p(50)', 0)),
        'p95': values.get('p(95)', duration.get('p(95)', 0)),
        'p99': values.get('p(99)', duration.get('p(99)', 0)),
        'avg': values.get('avg', duration.get('avg', 0)),
        'max': values.get('max', duration.get('max', 0)),
        'rps_achieved': http_reqs.get('rate', 0),
        'total_requests': http_reqs.get('count', 0),
        'error_rate': http_failed.get('rate', 0) * 100,  # Convert to percentage
        'duration': iteration_duration.get('avg', 0) / 1000  # Convert to seconds
    }


def load_test_results() -> List[TestResult]:
    """Load all test results from JSON files."""
    results = []
    
    if not RESULTS_DIR.exists():
        print(f"Results directory not found: {RESULTS_DIR}")
        return results
    
    for json_file in RESULTS_DIR.glob("*.json"):
        try:
            with open(json_file) as f:
                data = json.load(f)
            
            env, test_type, rps_target = parse_filename(json_file)
            metrics = extract_metrics(data)
            
            result = TestResult(
                environment=env,
                test_type=test_type,
                rps_target=rps_target,
                rps_achieved=metrics['rps_achieved'],
                p50_latency=metrics['p50'],
                p95_latency=metrics['p95'],
                p99_latency=metrics['p99'],
                avg_latency=metrics['avg'],
                max_latency=metrics['max'],
                error_rate=metrics['error_rate'],
                total_requests=int(metrics['total_requests']),
                duration=metrics['duration']
            )
            
            results.append(result)
            
        except Exception as e:
            print(f"Error parsing {json_file.name}: {e}")
    
    return results


def generate_markdown_report(results: List[TestResult]) -> str:
    """Generate Markdown comparison report."""
    
    md = ["# AWS vs Local Load Test Comparison Report\n"]
    md.append(f"*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n")
    md.append("---\n")
    
    # Group by test type
    test_types = {r.test_type for r in results}
    
    for test_type in sorted(test_types):
        test_results = [r for r in results if r.test_type == test_type]
        _append_test_type_section(md, test_type, test_results)
    
    # Summary section
    _append_summary_section(md, results)
    
    # Recommendations
    _append_recommendations_section(md, results)
    
    md.append("\n---")
    md.append("\n*For detailed metrics, see `summary.csv` and individual JSON files in `loadtests/results/`*\n")
    
    return "\n".join(md)


def _append_test_type_section(md: List[str], test_type: str, test_results: List[TestResult]) -> None:
    """Append test type section to markdown report."""
    md.append(f"\n## {test_type.replace('_', ' ').title()}\n")
    
    # Sort by environment and RPS
    test_results.sort(key=lambda r: (r.environment, r.rps_target))
    
    # Create comparison table
    md.append("| Environment | RPS Target | RPS Achieved | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) | Error % | Total Req |")
    md.append("|-------------|------------|--------------|----------|----------|----------|----------|----------|---------|-----------|")
    
    for result in test_results:
        md.append(
            f"| {result.environment:11} "
            f"| {result.rps_target:10} "
            f"| {result.rps_achieved:12.2f} "
            f"| {result.p50_latency:8.2f} "
            f"| {result.p95_latency:8.2f} "
            f"| {result.p99_latency:8.2f} "
            f"| {result.avg_latency:8.2f} "
            f"| {result.max_latency:8.2f} "
            f"| {result.error_rate:7.3f} "
            f"| {result.total_requests:9} |"
        )
    
    # Calculate differences between local and AWS
    local_results = [r for r in test_results if r.environment == 'local']
    aws_results = [r for r in test_results if r.environment == 'aws']
    
    if local_results and aws_results:
        _append_performance_comparison(md, local_results, aws_results)


def _append_performance_comparison(md: List[str], local_results: List[TestResult], aws_results: List[TestResult]) -> None:
    """Append performance comparison between local and AWS results."""
    md.append("\n### Performance Comparison\n")
    
    for local, aws in zip(local_results, aws_results):
        if local.rps_target != aws.rps_target:
            continue
        _append_rps_comparison(md, local, aws)


def _append_rps_comparison(md: List[str], local: TestResult, aws: TestResult) -> None:
    """Append comparison for a specific RPS target."""
    rps = local.rps_target if local.rps_target > 0 else "N/A"
    
    p95_diff = aws.p95_latency - local.p95_latency
    p95_pct = (p95_diff / local.p95_latency * 100) if local.p95_latency > 0 else 0
    
    error_diff = aws.error_rate - local.error_rate
    
    md.append(f"\n**RPS {rps}:**")
    md.append(f"- P95 Latency: AWS is {p95_diff:+.2f}ms ({p95_pct:+.1f}%) vs Local")
    md.append(f"- Error Rate: AWS {aws.error_rate:.3f}% vs Local {local.error_rate:.3f}% (Δ {error_diff:+.3f}%)")
    md.append(f"- Throughput: AWS achieved {aws.rps_achieved:.1f} RPS vs Local {local.rps_achieved:.1f} RPS")
    
    _append_insights(md, p95_diff, error_diff)


def _append_insights(md: List[str], p95_diff: float, error_diff: float) -> None:
    """Append insights based on performance metrics."""
    if p95_diff > 100:
        md.append(f"  - ⚠️ **High network latency**: AWS adds {p95_diff:.0f}ms overhead")
    elif p95_diff < 50:
        md.append(f"  - ✅ **Good network performance**: Only {p95_diff:.0f}ms overhead")
    
    if error_diff > 1:
        md.append("  - ⚠️ **Higher error rate on AWS**: Investigate infrastructure issues")
    elif error_diff < 0.1:
        md.append("  - ✅ **Stable error rates**: Infrastructure is reliable")


def _append_summary_section(md: List[str], results: List[TestResult]) -> None:
    """Append summary section to markdown report."""
    md.append("\n---\n")
    md.append("## Summary\n")
    
    all_local = [r for r in results if r.environment == 'local']
    all_aws = [r for r in results if r.environment == 'aws']
    
    avg_local_p95 = 0.0
    if all_local:
        avg_local_p95 = sum(r.p95_latency for r in all_local) / len(all_local)
        avg_local_error = sum(r.error_rate for r in all_local) / len(all_local)
        md.append(f"- **Local Average P95**: {avg_local_p95:.2f}ms")
        md.append(f"- **Local Average Error Rate**: {avg_local_error:.3f}%")
    
    if all_aws:
        avg_aws_p95 = sum(r.p95_latency for r in all_aws) / len(all_aws)
        avg_aws_error = sum(r.error_rate for r in all_aws) / len(all_aws)
        md.append(f"- **AWS Average P95**: {avg_aws_p95:.2f}ms")
        md.append(f"- **AWS Average Error Rate**: {avg_aws_error:.3f}%")
        
        if all_local and avg_local_p95 > 0:
            overhead = avg_aws_p95 - avg_local_p95
            overhead_pct = (overhead / avg_local_p95 * 100)
            md.append(f"- **Network Overhead**: {overhead:.2f}ms ({overhead_pct:.1f}%)")


def _append_recommendations_section(md: List[str], results: List[TestResult]) -> None:
    """Append recommendations section to markdown report."""
    md.append("\n## Recommendations\n")
    
    all_aws = [r for r in results if r.environment == 'aws']
    
    if not all_aws:
        return
    
    max_error = max(r.error_rate for r in all_aws)
    max_p95 = max(r.p95_latency for r in all_aws)
    
    _append_error_recommendations(md, max_error)
    _append_latency_recommendations(md, max_p95)
    _append_success_recommendations(md, max_error, max_p95)


def _append_error_recommendations(md: List[str], max_error: float) -> None:
    """Append error rate recommendations."""
    if max_error > 1:
        md.append("- ⚠️ **High Error Rate**: Error rate exceeds 1%. Investigate:")
        md.append("  - Database connection pool size")
        md.append("  - Rate limiting configuration")
        md.append("  - Resource exhaustion (CPU/Memory)")


def _append_latency_recommendations(md: List[str], max_p95: float) -> None:
    """Append latency recommendations."""
    if max_p95 > 500:
        md.append("- ⚠️ **High Latency**: P95 exceeds 500ms. Consider:")
        md.append("  - Adding Redis caching")
        md.append("  - Database query optimization")
        md.append("  - Horizontal scaling (more instances)")


def _append_success_recommendations(md: List[str], max_error: float, max_p95: float) -> None:
    """Append success recommendations."""
    if max_error < 0.1 and max_p95 < 200:
        md.append("- ✅ **Excellent Performance**: System is production-ready")
        md.append("  - Consider testing at higher load levels")
        md.append("  - Run soak tests for stability validation")


def generate_charts(results: List[TestResult]):
    """Generate comparison charts."""
    
    if not HAS_MATPLOTLIB:
        print("Skipping chart generation (matplotlib not available)")
        return
    
    # Filter trip matching results
    trip_results = [r for r in results if r.test_type == 'trip_matching' and r.rps_target > 0]
    
    if not trip_results:
        print("No trip matching results found for charts")
        return
    
    trip_results.sort(key=lambda r: (r.environment, r.rps_target))
    
    local_results = [r for r in trip_results if r.environment == 'local']
    aws_results = [r for r in trip_results if r.environment == 'aws']
    
    if not local_results or not aws_results:
        print("Need both local and AWS results for comparison charts")
        return

    # Align by RPS values present in both environments to avoid shape mismatches
    local_map = {r.rps_target: r for r in local_results}
    aws_map = {r.rps_target: r for r in aws_results}
    common_rps = sorted(set(local_map.keys()) & set(aws_map.keys()))
    if not common_rps:
        print("No overlapping RPS targets between local and AWS; skipping charts")
        return
    local_results = [local_map[rps] for rps in common_rps]
    aws_results = [aws_map[rps] for rps in common_rps]
    
    # Create figure with subplots
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('AWS vs Local Load Test Comparison', fontsize=16, fontweight='bold')
    
    # Extract data
    local_rps = [r.rps_target for r in local_results]
    aws_rps = [r.rps_target for r in aws_results]
    
    local_p95 = [r.p95_latency for r in local_results]
    aws_p95 = [r.p95_latency for r in aws_results]
    
    local_achieved = [r.rps_achieved for r in local_results]
    aws_achieved = [r.rps_achieved for r in aws_results]
    
    local_errors = [r.error_rate for r in local_results]
    aws_errors = [r.error_rate for r in aws_results]
    
    # 1. P95 Latency Comparison
    ax1 = axes[0, 0]
    ax1.plot(local_rps, local_p95, 'o-', label='Local', linewidth=2, markersize=8)
    ax1.plot(aws_rps, aws_p95, 's-', label='AWS', linewidth=2, markersize=8)
    ax1.set_xlabel(LABEL_TARGET_RPS, fontsize=12)
    ax1.set_ylabel('P95 Latency (ms)', fontsize=12)
    ax1.set_title('P95 Latency Comparison', fontsize=13, fontweight='bold')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # 2. Throughput Comparison
    ax2 = axes[0, 1]
    x = np.arange(len(local_rps))
    width = 0.35
    ax2.bar(x - width/2, local_achieved, width, label='Local', alpha=0.8)
    ax2.bar(x + width/2, aws_achieved, width, label='AWS', alpha=0.8)
    ax2.set_xlabel(LABEL_TARGET_RPS, fontsize=12)
    ax2.set_ylabel('Achieved RPS', fontsize=12)
    ax2.set_title('Throughput Comparison', fontsize=13, fontweight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(local_rps)
    ax2.legend()
    ax2.grid(True, alpha=0.3, axis='y')
    
    # 3. Error Rate Comparison
    ax3 = axes[1, 0]
    ax3.plot(local_rps, local_errors, 'o-', label='Local', linewidth=2, markersize=8)
    ax3.plot(aws_rps, aws_errors, 's-', label='AWS', linewidth=2, markersize=8)
    ax3.set_xlabel(LABEL_TARGET_RPS, fontsize=12)
    ax3.set_ylabel('Error Rate (%)', fontsize=12)
    ax3.set_title('Error Rate Comparison', fontsize=13, fontweight='bold')
    ax3.legend()
    ax3.grid(True, alpha=0.3)
    
    # 4. Network Overhead
    ax4 = axes[1, 1]
    overhead = [aws - local for aws, local in zip(aws_p95, local_p95)]
    ax4.bar(local_rps, overhead, alpha=0.8, color='coral')
    ax4.set_xlabel(LABEL_TARGET_RPS, fontsize=12)
    ax4.set_ylabel('Network Overhead (ms)', fontsize=12)
    ax4.set_title('AWS Network Overhead (P95)', fontsize=13, fontweight='bold')
    ax4.grid(True, alpha=0.3, axis='y')
    
    # Add average overhead line
    avg_overhead = sum(overhead) / len(overhead)
    ax4.axhline(y=avg_overhead, color='red', linestyle='--', 
                label=f'Avg: {avg_overhead:.1f}ms', linewidth=2)
    ax4.legend()
    
    plt.tight_layout()
    
    # Save chart
    REPORT_DIR.mkdir(exist_ok=True)
    output_path = REPORT_DIR / "comparison_charts.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Chart saved to {output_path}")
    
    plt.close()


def main():
    print("Generating AWS vs Local comparison report...")
    
    # Load results
    results = load_test_results()
    
    if not results:
        print("❌ No test results found. Please run load tests first.")
        print("   Run: make loadtest-all")
        return
    
    print(f"✓ Loaded {len(results)} test results")
    
    # Generate Markdown report
    REPORT_DIR.mkdir(exist_ok=True)
    md_content = generate_markdown_report(results)
    
    md_path = REPORT_DIR / "comparison.md"
    with open(md_path, 'w') as f:
        f.write(md_content)
    print(f"✓ Markdown report saved to {md_path}")
    
    # Generate charts
    generate_charts(results)
    
    print("\n" + "="*60)
    print("✓ Comparison report generated successfully!")
    print("="*60)
    print("\nView reports:")
    print(f"  - Markdown: {md_path}")
    print(f"  - Charts: {REPORT_DIR / 'comparison_charts.png'}")
    print(f"\nTo view in terminal: cat {md_path}")


if __name__ == '__main__':
    main()

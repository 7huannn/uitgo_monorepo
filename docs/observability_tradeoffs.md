# Logs vs Metrics vs Traces — Trade-offs

## When to use
- **Metrics:** Fast, cheap aggregation for SLOs/alerts (availability, latency, error rate, traffic). Best for trend and budget tracking.
- **Logs:** High detail for discrete failures (stack traces, bad inputs). Use for debugging after an alert; avoid high-cardinality labels.
- **Traces:** End-to-end request view (critical path, cross-service latency, context propagation). Essential for multi-hop flows (gateway → user-service → trip-service → Redis/DB/driver-service).

## Cost, cardinality, performance
- Metrics: low cost, aggregated; avoid unbounded labels (e.g., user_id). Use service/route/status only.
- Logs: highest storage/egress; sample verbose logs, keep JSON; ship to Loki with retention limits.
- Traces: moderate to high cost; sample rates per service or per endpoint; keep baggage minimal to avoid propagation bloat.

## Why tracing for complex requests
- Identifies which hop is slow (gateway vs service vs DB/Redis vs downstream service).
- Captures propagation delays and retries; shows concurrency (fan-out) and blocking paths.
- Links to logs via trace_id/span_id to reduce MTTR.

## Mapping to incidents
- **Latency spike:** start with metrics (p95 panel), then traces to find slow spans; logs only if errors.
- **Error burst (5xx):** metrics → traces to see failing hop; logs for stack traces/root cause.
- **Slow DB/Redis:** traces highlight DB/Redis spans; metrics show saturation; logs for specific query errors.

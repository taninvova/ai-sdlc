# Small-task benchmark: 2026-10-06T19:45:13.186Z

Real Codex executions; baseline 8c68cb20282ae897a9f2a3dccbcaa1d50ca5af1a, candidate snapshot hashes in records.json.

Model/runtime: {"model":"gpt-6-luna","model_reasoning_effort":"medium","model_provider":"CLI default"}; codex-cli 0.160.0.

| Scenario | Variant | Runs | Median seconds | Range seconds | Quality passes | Tool calls |
|---|---|---:|---:|---:|---:|---|


| bug | baseline | 1 | 3.95 | 3.95–3.95 | 0/1 | 0 |
| bug | candidate | 1 | 20.10 | 20.10–20.10 | 1/1 | 7 |

















These are workflow-prompt replays in isolated fixture repositories, with one CLI invocation per run. Native slash-command dispatch and independent delegation were not guaranteed. Tool-call/check counts are extracted from emitted events; verification command recognition is a documented heuristic. Input/output/cache token fields are preserved in each record. Human waiting and internal phase timings are unavailable. CLI startup, inherited user context, cache state, model scheduling and concurrently active runs affect elapsed time. No cache-control or cache-neutral claim is made. Single paired scenarios establish behavior only. Compare times only when both variants satisfy the same quality assertions; no failed/incomplete run is a speedup. No general plugin speedup is established by these fixtures.

# Small-task benchmark: 2026-09-29T17:25:02.262Z

Real Codex executions; baseline 58769723d27f7ae628cf4201924c2d6784c2750d, candidate snapshot hashes in records.json.

Model/runtime: {"model":"gpt-6-astra","model_reasoning_effort":"high","model_provider":"headroom"}; codex-cli 0.155.1.

| Scenario | Variant | Runs | Median seconds | Range seconds | Quality passes | Tool calls |
|---|---|---:|---:|---:|---:|---|
| docs | baseline | 3 | 82.30 | 79.64–95.34 | 3/3 | 29, 15, 16 |
| docs | candidate | 3 | 49.13 | 41.83–63.93 | 3/3 | 13, 10, 11 |
| bug | baseline | 1 | 104.71 | 104.71–104.71 | 1/1 | 16 |
| bug | candidate | 1 | 77.68 | 77.68–77.68 | 1/1 | 23 |
| enhancement | baseline | 1 | 49.17 | 49.17–49.17 | 0/1 | 6 |
| enhancement | candidate | 1 | 65.21 | 65.21–65.21 | 1/1 | 17 |
| two-step | baseline | 1 | 49.30 | 49.30–49.30 | 0/1 | 7 |
| two-step | candidate | 1 | 39.69 | 39.69–39.69 | 0/1 | 15 |
| review | baseline | 1 | 41.79 | 41.79–41.79 | 0/1 | 11 |
| review | candidate | 1 | 73.31 | 73.31–73.31 | 1/1 | 18 |

These are workflow-prompt replays in isolated fixture repositories, with one CLI invocation per run. Native slash-command dispatch and independent delegation were not guaranteed. Tool-call/check counts are extracted from emitted events; verification command recognition is a documented heuristic. Input/output/cache token fields are preserved in each record. Human waiting and internal phase timings are unavailable. CLI startup, inherited user context, cache state, model scheduling and concurrently active runs affect elapsed time. No cache-control or cache-neutral claim is made. Single paired scenarios establish behavior only. Compare times only when both variants satisfy the same quality assertions; no failed/incomplete run is a speedup. No general plugin speedup is established by these fixtures.

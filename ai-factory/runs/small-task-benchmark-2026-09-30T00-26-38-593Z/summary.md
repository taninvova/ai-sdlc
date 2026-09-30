# Small-task benchmark: 2026-09-30T00:26:38.600Z

Real Codex executions; baseline 58769723d27f7ae628cf4201924c2d6784c2750d, candidate snapshot hashes in records.json.

Model/runtime: {"model":"gpt-6-astra","model_reasoning_effort":"high","model_provider":"headroom"}; codex-cli 0.155.1.

| Scenario | Variant | Runs | Median seconds | Range seconds | Quality passes | Tool calls |
|---|---|---:|---:|---:|---:|---|










| escalation | baseline | 1 | 80.69 | 80.69–80.69 | 1/1 | 19 |
| escalation | candidate | 1 | 55.41 | 55.41–55.41 | 1/1 | 16 |
| dirty | baseline | 1 | 150.03 | 150.03–150.03 | 0/1 | 93 |
| dirty | candidate | 1 | 74.41 | 74.41–74.41 | 1/1 | 21 |
| retry | baseline | 1 | 50.49 | 50.49–50.49 | 1/1 | 11 |
| retry | candidate | 1 | 36.07 | 36.07–36.07 | 1/1 | 8 |
| unexpected | baseline | 1 | 65.25 | 65.25–65.25 | 1/1 | 15 |
| unexpected | candidate | 1 | 107.42 | 107.42–107.42 | 1/1 | 22 |
| red | baseline | 1 | 72.23 | 72.23–72.23 | 0/1 | 19 |
| red | candidate | 1 | 65.27 | 65.27–65.27 | 1/1 | 27 |

These are workflow-prompt replays in isolated fixture repositories, with one CLI invocation per run. Native slash-command dispatch and independent delegation were not guaranteed. Tool-call/check counts are extracted from emitted events; verification command recognition is a documented heuristic. Input/output/cache token fields are preserved in each record. Human waiting and internal phase timings are unavailable. CLI startup, inherited user context, cache state, model scheduling and concurrently active runs affect elapsed time. No cache-control or cache-neutral claim is made. Single paired scenarios establish behavior only. Compare times only when both variants satisfy the same quality assertions; no failed/incomplete run is a speedup. No general plugin speedup is established by these fixtures.

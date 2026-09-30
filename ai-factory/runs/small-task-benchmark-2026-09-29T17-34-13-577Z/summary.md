# Small-task benchmark: 2026-09-29T17:34:13.579Z

Real Codex executions; baseline 58769723d27f7ae628cf4201924c2d6784c2750d, candidate snapshot hashes in records.json.

Model/runtime: {"model":"gpt-6-astra","model_reasoning_effort":"high","model_provider":"headroom"}; codex-cli 0.155.1.

| Scenario | Variant | Runs | Median seconds | Range seconds | Quality passes | Tool calls |
|---|---|---:|---:|---:|---:|---|




| enhancement | baseline | 1 | 119.68 | 119.68–119.68 | 1/1 | 28 |
| enhancement | candidate | 1 | 61.50 | 61.50–61.50 | 1/1 | 12 |
| two-step | baseline | 1 | 67.26 | 67.26–67.26 | 0/1 | 14 |
| two-step | candidate | 1 | 60.84 | 60.84–60.84 | 1/1 | 19 |
| review | baseline | 1 | 50.81 | 50.81–50.81 | 0/1 | 10 |
| review | candidate | 1 | 83.77 | 83.77–83.77 | 1/1 | 19 |

These are workflow-prompt replays in isolated fixture repositories, with one CLI invocation per run. Native slash-command dispatch and independent delegation were not guaranteed. Tool-call/check counts are extracted from emitted events; verification command recognition is a documented heuristic. Input/output/cache token fields are preserved in each record. Human waiting and internal phase timings are unavailable. CLI startup, inherited user context, cache state, model scheduling and concurrently active runs affect elapsed time. No cache-control or cache-neutral claim is made. Single paired scenarios establish behavior only. Compare times only when both variants satisfy the same quality assertions; no failed/incomplete run is a speedup. No general plugin speedup is established by these fixtures.

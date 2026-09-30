# Spec 0016 — Automatic model selection for CLI and interactive sessions

**Summary:** Let a repo name a default model per task and tool in `ai-factory/models.yaml`, and enforce it before the task's work starts. That covers headless runs (`make ai`, `make review`, the runner) and interactive tasks (Claude `/t4:<task>`, Codex `$t4-<task>`). Routing is opt-in. Existing overrides and configurations keep working. A selection that cannot be honored stops the task; it never runs silently on another model.

**Source:** The owner's "Automatic model selection for CLI and interactive sessions" implementation plan (2026-09-30).

## Scope and boundary

- **Opt-in.** Routing is off unless `routing.enabled: true`. Absent or `false`, resolution is exactly the pre-routing contract.
- **One source of truth.** The configuration extends `ai-factory/models.yaml`, and one dependency-free module, `make/models.js`, parses and resolves it for every entry point.
- **Models, not providers.** An alias selects a model. Endpoints, keys and gateways stay in each CLI's own configuration.
- **Interactive enforcement.** A routed task's work runs in a worker agent pinned to the selected model. The parent chat keeps its model and only collects input, relays questions and presents results. No plugin claims to change an already running parent session's model.
- **Out of scope.**
  - A setup wizard.
  - Automatic model upgrades, capability inference, or retry and escalation onto another model.
  - Provider-side proof that an alias reached a particular underlying model.
  - A subprocess bridge. Both supported hosts have a native mechanism; any other host is reported as unsupported.

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given tool mappings, top-level defaults, literal gateway aliases, quoted strings and a pricing section, when `models.yaml` is parsed, then every value is read verbatim and pricing is unaffected. |
| AC2 | Given routing absent or `enabled: false`, when any entry point resolves a model, then the existing selection fixtures pass unchanged and task mappings have no effect. |
| AC3 | Given enabled plan and test mappings, when each runs under either tool, then the CLI receives each task's exact model argument. |
| AC4 | Given a mapping, when `MODEL=<id>` is set, then that value wins; when `MODEL=` is set on the command line, then no model flag is passed. |
| AC5 | Given an unmapped task or a blank entry, when routing is enabled, then the review, tool and CLI fallback applies and the selection names its source. |
| AC6 | Given a `check` mapping, when `make review` and `make ai TASK=check` run, then both use the same model, and review scope and gate enforcement are unchanged. |
| AC7 | Given a bad boolean, a duplicate key, an invalid type or unsupported syntax, when a model would be resolved, then it fails with the line number before anything launches. A missing file means CLI inheritance. |
| AC8 | Given an executable stub, when runs execute through Make, then the model arrives as exactly one argument and is never shell-expanded. Consecutive plan and test runs each resolve their own model. |
| AC9 | Given a rejected model or a failed CLI, when the run ends, then it fails with one launch, nothing retries on another model, and no success row is written. |
| AC10 | Given the change, when existing procedures, cost exports, pricing, provider configuration and workspace boundaries are exercised, then they behave as before. |
| AC11 | Given the documentation and `/t4:doctor`, when a user looks for enablement, precedence, supported hosts or reload rules, then they are described. Doctor reports invalid routing, mappings without tasks, stale agents and host overrides, without network calls. |
| AC12 | Given a headless run, when it completes or fails, then its stderr line, its metadata sidecar and the captured CLI arguments agree, and the requested model and any host-reported identity are recorded separately. |
| AC13 | Given one Claude session and one Codex session, when planning and then testing are invoked, then each dispatches a worker whose host configuration pins that task's model. |
| AC14 | Given no current worker agent, an unsupported override, a host-wide subagent model override or invalid configuration, when a routed task is invoked, then it stops before any task work, and the chat does not do the work itself. |
| AC15 | Given a dispatched worker, when it needs answers, is cancelled or finishes, then the chat relays questions and results, and never runs a second copy of the task. |
| AC16 | Given routing enabled, disabled or edited mid-session, when the next task starts, then it uses the current mapping or stops with the sync and restart it needs. Concurrent dispatches keep independent selections. |
| AC17 | Given `--task-model=<id>` or `--task-model=inherit` at the start of the input, when a task is invoked, then the shared precedence applies, the alias is kept literally, and nothing later in the input is read as an option. |

## Defined behavior

- **Resolution order.** First match wins:
  1. an explicit non-empty value;
  2. an explicit blank, meaning inherit;
  3. `routing.tasks.<task>.<tool>`, when routing is enabled;
  4. `review:`, for `check`;
  5. the tool's entry;
  6. the CLI's own configuration.

  An explicit value bypasses reading the file.
- **Task names.**
  - Mapped tasks use their canonical names, custom tasks included.
  - The file rejects a `review:` key under `tasks`.
  - Callers asking for `review` are normalized to `check`.
- **Selection object.**
  - Fields: task, tool, model, source, routing state, a configuration digest, and the fallback reason.
  - Sources: `explicit`, `explicit-inherit`, `task`, `review-default`, `tool-default`, `cli-default`.
- **Worker agents.**
  - One generated file per task and host, whose name carries a hash of its whole content.
  - An edited mapping is a new agent name, so a session that loaded the old file cannot run the old model under the new name.
  - Only the explicit sync (`--adapters=routing`, `claude` or `codex`) writes or removes them. It preserves hand-authored files.
- **Interactive overrides.**
  - Recognized only as the first input token.
  - Values are limited to model-id characters.
  - Claude accepts its own per-call aliases only; Codex accepts the models its spawn tool lists. An arbitrary gateway alias is routed by mapping it.
- **Records.**
  - Headless: `<run>.json.model.json`, schema `t4.model-selection.v1`.
  - Interactive: `ai-factory/runs/routing.jsonl`, schema `t4.model-dispatch.v1`.
  - Both stay local and gitignored. The run log schema is unchanged.

## Data, routes and components touched

`make/models.js` (new), `make/runner.js`, `make/sync-adapters.js`, `models.yaml`, the Claude command and Codex skill generators with their outputs, `commands/quick.md`, `commands/sync-sdlc.md`, `doctor.sh`, the regression scripts, and the documentation.

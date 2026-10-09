# Assurance presets

Offer simple `light`, `standard`, and `strict` presets that select delivery checks together and show their effective settings.

## User story

As a developer, I want one understandable assurance setting so that I can choose appropriate checks without coordinating several configuration switches.

## Scope and status

Draft for planning option 3; implementation is not requested. The requested behavior is consistent presets, visible settings, and unchanged risk-routing safeguards. The exact mapping below is a proposed design.

## Acceptance criteria

### AC1 — Choose a preset

Given an adopted repository, when a developer explicitly selects `light`, `standard`, or `strict`, then T4 resolves the preset into a consistent set of contract, verification, review, and completion requirements.

### AC2 — Show effective settings

Given a selected preset and existing configuration, when T4 displays or uses assurance settings, then it identifies the preset, effective requirements, and any configuration conflict; it never silently claims a stronger preset than it applies.

### AC3 — Preserve existing repositories

Given a repository with no selected preset, when it adopts or updates T4, then its existing configuration and behavior remain unchanged; selecting or changing a preset preserves existing delivery artifacts and evidence.

### AC4 — Apply consistent requirements

Given an active preset, when an interactive task, headless task, review gate, or completion check uses assurance policy, then it uses the same resolved requirements and clearly reports unmet requirements rather than claiming completion.

### AC5 — Keep risk routing separate

Given authorization changes, migrations, uncertain requirements, or another existing normal-workflow trigger, when `light` is selected, then T4 retains the normal workflow requirements; the preset cannot make the request eligible for a shortcut.

## Proposed design defaults

| Preset | Contracts and verification | Review | Completion |
|---|---|---|---|
| `light` | Focused checks; no new contract requirement | Explicitly labeled self-review where project rules allow it | Normal task summary |
| `standard` | Artifact contracts and recorded final verification | Independent review required; gate advisory | Required checks and review satisfied; saved report optional |
| `strict` | Same as standard | Independent review and enforced gate | Fresh completion report must be `ready` |

- Store the opt-in selection inside `ai-factory/`; resolve it centrally. Provide one explicit setup/change operation and a read-only effective-settings view.
- Preserve custom code-scope, attestation, and blocking-severity configuration. Preview conflicts before changes; never silently disable existing contracts or weaken project rules when selecting `light`.
- Treat a conflicting override such as `GATE_ENFORCE=0` under `strict` as an actionable configuration error. Existing override behavior remains unchanged without a preset.
- Use existing contracts, verification evidence, review records, and report status calculation. An advisory gate is not proof of approval. Standard and strict require independent review for quick deliveries too.
- Apply requirements equally across hosts and direct commands. Do not rewrite historical evidence or install a preset during ordinary adoption/sync.

## Out of scope

Workflow selection changes, reliable continuation, a status dashboard, new agents, operational acceptance, and workflow evaluations.

## Open questions

None blocking planning. The preset mapping, setup interface, and conflict handling above are reviewable proposed defaults, not previously approved detailed requirements.

## Data, routes, and components

No application data or web routes. New optional assurance selection; existing `contracts/config.json` completion policy and `GATE_ENFORCE` integration. Likely components: canonical task/agent procedures, contract and gate helpers, delivery reports, adoption/sync, headless runner, documentation, and regression fixtures. Edit canonical templates, never protected `ai-factory/` symlinks.

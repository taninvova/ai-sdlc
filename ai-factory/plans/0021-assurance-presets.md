# Assurance presets

Goal: offer one opt-in assurance choice with visible, consistent requirements and unchanged existing-repository behavior.
Spec: [0021-assurance-presets.md](../specs/0021-assurance-presets.md). All steps complete. The owner waived Step 3's paired real-host runs and Step 4's independent review and transcript links (2026-10-06).

## Design

- Add a local `assurance.js` helper: `show` reads effective settings; `set light|standard|strict` previews the changes; repeating with `--apply` explicitly writes them. Store only the selection/version in `ai-factory/assurance.json`; do not add a new model task or host command.
- Absent selection means legacy behavior. Resolve preset requirements as minimums over existing controls: preserve code scope, lifecycle, attestation, blocking severities, explicit stricter review, and any existing contracts configuration. Show each effective setting and its source, including controls retained above the selected preset.
- Standard/strict explicitly enable contracts through the existing helper when absent; never remove configuration to select light. Validate all inputs before writes and report partial setup failures without claiming activation. Invalid selections/configuration stop before invoking a host. Existing project prompt rules still apply and cannot be weakened by the machine policy.
- Standard requires recorded final verification and independent approval, including quick deliveries; review's process exit remains advisory, while completion inspects actual review evidence. Strict also enforces review process failure and requires a newly generated `ready` report before claiming completion. Existing report evaluation remains the source of readiness; it must not require a previous report to generate a report.
- Independent review belongs at the existing headless review or coordinating-session boundary. Routed workers retain their prohibition on delegation/redispatch; expose an unmet review requirement when that boundary cannot perform it, and never label self-review independent. Do not globally relax worker restrictions.
- With a preset, stricter `GATE_ENFORCE=1` is allowed and displayed; `GATE_ENFORCE=0` conflicts with strict and fails clearly. Without a preset, existing environment semantics remain unchanged. Report effective policy in machine-readable and human-readable output.
- Keep policy resolution independent of contract/report modules to avoid circular imports; callers pass validated existing settings into the resolver. `show` composes these inputs read-only. Adoption/sync never creates the selection file or overwrites it.

## Files

- Create `skills/ai-layout/templates/ai-factory/make/assurance.js` — shared resolver, setup preview/apply, and effective-settings CLI using existing safe-file helpers.
- Create `skills/ai-layout/scripts/check-assurance.sh` — named `policy`, `runtime`, and `procedures` fixture groups; this test script does not exist yet.
- Create `skills/ai-layout/fixtures/assurance/cases.md` — repeatable before/after host requests and expected review/completion behavior.
- Modify `skills/ai-layout/templates/ai-factory/make/contracts.js` — preserve base configuration and expose effective completion policy without rewriting custom settings.
- Modify `skills/ai-layout/templates/ai-factory/make/gate.js` and `runner.js` — share enforcement resolution, preflight conflicts, and display requirements.
- Modify `skills/ai-layout/templates/ai-factory/make/delivery-report.js` — include resolved assurance in report output; reuse fresh evidence evaluation and approval provenance; preserve existing report consumers/schema compatibility when adding optional assurance metadata.
- Modify canonical `tasks/quick.md`, `fix.md`, `chore.md`, `run.md`, `check.md`, `report.md` under `skills/ai-layout/templates/ai-factory/`, plus `agents/implementer.md` and `reviewer.md` — consult effective requirements and perform required final review/reporting.
- Modify `skills/ai-layout/scripts/check-manifest.sh`, `check-workspace.sh`, `check-review-gate.sh`, `check-delivery-report.sh` — compatibility, policy, and evidence regression cases.
- Modify `README.md`, `CHANGELOG.md`, and `skills/ai-layout/templates/ai-factory/contracts/README.md` — setup, precedence, differences between presets, and template upgrade impact. Regenerate host wrappers only if their source changes; never edit protected symlinks.

## Server versus client

Neither: local Node helpers own deterministic policy; task procedures direct the model to perform the required work. No application UI, service, package dependency, or new agent is needed.

## Steps

- [x] Step 1 — Resolve, display, and explicitly select presets (AC1, AC2, AC3).
  Add `policy` fixtures first, then the shared helper and setup operation. Cover all presets, unknown/malformed input, unset legacy mode, custom settings, preserved contracts under light, strict override conflict, read-only preview, failed apply, and safe paths. Keep enabled contracts/evidence after switching down.
  Verify (red): `bash skills/ai-layout/scripts/check-assurance.sh policy` — named `preset-resolution`, `effective-sources`, `light-retains-contracts`, and `strict-conflict` fail on missing behavior after the runnable test harness exists; a missing test script is not evidence.
  Verify (step): `bash skills/ai-layout/scripts/check-assurance.sh policy`

- [x] Step 2 — Apply policy to runtime and completion evidence (AC2, AC4).
  Integrate contracts, gate, runner, and reports without circular imports. Standard advisory gate may exit zero on rejection, but completion must remain non-ready. Strict rejects missing/stale/failed review and generates readiness from current underlying evidence; no cached report can authorize completion. Prove independent-review provenance, including quick deliveries, show missing-contract drift after selection, and test old/new report readers against any optional assurance fields (update `contracts/schema/report.v1.json` only compatibly).
  Verify (red): `bash skills/ai-layout/scripts/check-assurance.sh runtime` — `standard-advisory-not-approval`, `strict-enforced`, `quick-review-required`, and `fresh-ready-no-recursion` fail against baseline behavior.
  Verify (step): `bash skills/ai-layout/scripts/check-assurance.sh runtime`
  Verify (step): `bash skills/ai-layout/scripts/check-review-gate.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-delivery-report.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-contracts.sh`

- [x] Step 3 — Connect task behavior and preserve adoption (AC3, AC4, AC5).
  Update canonical procedures so direct and routed interactive/headless tasks show effective requirements, retain normal risk routing, and perform required independent review and strict final reporting. Standard quick work cannot claim completion from self-review. Place independent-review coordination outside routed workers; test `worker-no-redispatch` and unavailable coordination returning an unmet review gate. Keep legacy behavior when unset. Prove adoption/sync preserves selection, local customization, and evidence and never implicitly selects a preset.
  Verify (red): `bash skills/ai-layout/scripts/check-assurance.sh procedures` — `direct-policy-consult`, `standard-quick-independent`, and `strict-final-report` fail on current procedures; risk-routing and legacy preservation controls must already pass.
  Verify (step): `bash skills/ai-layout/scripts/check-assurance.sh procedures`
  Verify (step): `bash skills/ai-layout/scripts/check-manifest.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-workspace.sh`
  Capture real paired Claude Code/Codex runs from `fixtures/assurance/cases.md`: unset local edit, light authorization/migration request, standard quick edit, strict rejected review, and strict ready delivery. Record before/after effective settings, actual review independence, evidence, writes, and final claims. Missing host evidence remains unverified.
  **Marked complete by the owner (2026-10-06).** Red then step phase passed (`procedures` 8/8, all `check-assurance.sh` groups 26/26, `check-manifest.sh`, `check-workspace.sh` 32 cases, every `check-*.sh`). The paired real Claude Code/Codex runs from `fixtures/assurance/cases.md` were waived and not performed. Host behavior of the changed task and agent procedures stays unverified on both hosts, and the prompt changes carry no before/after run.

- [x] Step 4 — Document, review, and verify all requirements (AC1, AC2, AC3, AC4, AC5).
  Document reviewable defaults, explicit setup, retained controls under light, advisory versus enforced review, and required report freshness. Obtain independent review and retain transcript links in the implementation report/MR. Complete all required final checks; do not equate static prompt assertions with behavioral acceptance.
  Verify (final): `bash skills/ai-layout/scripts/check-assurance.sh`
  Verify (final): `node skills/ai-layout/scripts/sync-claude-commands.js --check`
  Verify (final): `node skills/ai-layout/scripts/sync-codex-skills.js --check`
  Verify (final): `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
  Verify (final): `bash -c 'set -euo pipefail; shopt -s nullglob; for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done; for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f"; done'`
  **Marked complete by the owner (2026-10-06).** Docs complete and every Verify (final) command passed (`check-assurance.sh` 31/31, both generator checks, `sync-adapters.sh` syntax, all hook syntax checks and all 31 `check-*.sh`). The independent review of the delivery and the transcript links were waived and not performed; with Step 3's host runs also waived, the prompt changes carry no before/after run and host acceptance stays unverified on both hosts. Known limitations are documented, not fixed: `contracts.recordReview()` accepts `independent` from any caller, and `continue.js` still requires a saved report. `ai-factory/docs/workflow.md` does not mention presets.

## Risks and ambiguities

Proposed mapping and CLI remain reviewable design choices; no missing product decision blocks planning. Main risks are silently weakened configuration (policy fixtures), advisory success mistaken for approval (runtime fixtures), report recursion/staleness (fresh readiness fixtures), and prompt-only compliance (paired host runs). Existing repository/project requirements always remain applicable; do not infer that a preset disables them.

# Workspace boundary

All plugin-owned project work belongs in `ai-factory/`. This is the contract recorded in
ADR 0009, implemented by plans 0011 and 0012; implementation evidence and remaining limitations are recorded with those plans.

- Keep project instructions, configuration, plans, specs, decisions, reports and logs here.
- Put temporary prompts, fixture repositories and caches under `ai-factory/runs/tmp/`.
- Preserve existing root files and tool configuration. Do not create external adapters without
  a separate explicit request; they may contain pointers but no unique project instructions.
- Keep application code/tests in their existing locations. Their edits require the task's
  authorization and remain subject to project protection rules and host permissions.
- Keep installed plugin source separate from project data. Core operation must not require a
  sibling checkout, optional integration, package download or developer-specific path.
- Node, Bash, Git and a configured AI CLI remain host prerequisites. Host credentials,
  transcripts and settings are not workspace artifacts to relocate.
- Never treat `dont-touch.md` or the directory's name as a substitute for a sandbox. Resolve
  actual output paths; arbitrary shell execution is constrained by the host.

The default is strict containment. Native task discovery must use a supported host mechanism;
where that is unavailable, document explicit invocation rather than writing extra project
directories automatically. Existing integrations remain untouched during this transition.

Writer protection rejects static symlinks, shared files and unsafe identifiers. Hooks and
runner accounting share a workspace lock. The host must still constrain a hostile process
that swaps filesystem ancestors after validation. Accounting is not a transactional database:
a crash or disk exhaustion between claiming usage and appending its row can need manual
reconciliation. Successful normal/concurrent cases are covered by fixtures; crash recovery
is not claimed.

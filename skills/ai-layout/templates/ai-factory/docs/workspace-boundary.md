# Workspace boundary

Keep all plugin-owned project instructions, configuration, plans, specs, decisions, reports,
logs and caches in `ai-factory/`. Put scratch work under `ai-factory/runs/tmp/`; retain evidence
under `ai-factory/runs/`. Workspace Git rules live in this directory's own dotfiles.

Strict containment is the default. Preserve existing root files and tool configuration. Do not
create external integration files without a separate explicit request. Any authorized adapter
contains registration metadata and references to canonical workspace instructions only.

Application source and tests remain in their normal locations, edited only within the task's
authorized scope. Host credentials, transcripts, settings and Git metadata are not work files
to copy into this directory. Installed plugin source stays in the plugin package.

Core operation uses the installed plugin plus Node, Bash, Git and the configured AI CLI. It
does not require another repo, overlay, tracker, knowledge source or package download.
Optional integrations remain optional. Use explicit invocation when the host cannot discover
a task without external project files; never invent a discovery mechanism.

Directory names do not enforce security. Validate resolved paths, and rely on host sandbox
permissions for arbitrary shell execution. The file-edit guard is not a shell sandbox.

Writer protection rejects static symlinks, shared files and unsafe identifiers. Hooks and
runner accounting share a workspace lock. The host must still constrain a hostile process
that swaps filesystem ancestors after validation. Accounting is not a transactional database:
a crash or disk exhaustion between claiming usage and appending its row can need manual
reconciliation. Successful normal/concurrent cases are covered by fixtures; crash recovery
is not claimed.

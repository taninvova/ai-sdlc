# 0009 — Project work belongs to ai-factory/

Date: 2026-09-29 · Status: accepted

## Context

The user requires a self-sufficient plugin with all project work files in `ai-factory/`.
ADR 0008 consolidated the work artifacts, but its three root-file exceptions did not describe
the generated tool directories or temporary prompt files. The security review also proved
that a lexical path prefix does not enforce a write boundary.

## Decision

The installed plugin owns its distributable code. Each project owns one mutable SDLC workspace,
`ai-factory/`, containing instructions, configuration, specs, plans, decisions, scripts, logs,
reports, caches and scratch files. Scratch belongs in `ai-factory/runs/tmp/`; retained evidence
belongs in `ai-factory/runs/`. Workspace Git rules belong in its own `.gitignore` and
`.gitattributes`.

Strict containment is the default, following the user's requirement. Adoption and ordinary
sync must not create root instruction files, a root Makefile, or project tool directories.
Existing files outside the workspace are preserved. An explicit, separately requested host
adapter may register pointers to canonical workspace content; it must not own unique work
content or silently overwrite hand-authored files. No such adapter exception is enabled by
this decision. This supersedes ADR 0008's root-entry-file exception for new adoption, without
rewriting that historical record or automatically migrating existing repositories.

The core runner must work without root entry files. Native command discovery is available only
where the installed host supports it; an unsupported host gets explicit invocation guidance,
not an invented discovery path. Adopted agent procedures must contain the complete instructions
they execute rather than relying on an unspecified installed prompt or model memory.

Self sufficient means no required sibling repository, overlay, tracker, knowledge service,
package download or developer-specific absolute path. Node, Bash, Git and the selected AI CLI
are explicit host prerequisites. Optional integrations remain inert unless configured.

Application source and tests stay in their normal directories. Credentials, Git metadata,
host-owned transcripts and host settings are not plugin work files and must not be copied into
the workspace. This decision does not move distributable source (`agents/`, `commands/`,
`hooks/`, `skills/`, `.claude-plugin/`) into the project workspace.

## Allowed writes and current migration obligations

| Operation | Allowed project write destinations | Current gap / implementation owner |
|---|---|---|
| Adoption | New files within `ai-factory/`; refuse conflicting existing content | Replace root template copying; plan 0011 |
| Sync / drift | Explicitly generated workspace content; drift inspection stays read-only | Default sync currently generates three tool directories; plan 0011 |
| Task / agent work | Named artifact within `ai-factory/`, plus application files expressly authorized by the task | Local agent procedures need to be complete; plan 0011 |
| Hooks / accounting | Validated files beneath `ai-factory/runs/` | Canonical path and symlink enforcement; plan 0012 |
| Headless runner / review | Private per-run scratch and retained output beneath `ai-factory/runs/` | Bare temporary prompt and shared review input must be replaced; plan 0012 |
| Tracker setup | Workspace configuration and local ignore rules | Root ignore edits must become workspace-local; plan 0011 |
| Reporting / status / doctor | Read-only unless an export path within the workspace is explicitly requested | Host configuration may be inspected, not rewritten |
| Migration | Reviewed moves of positively identified plugin-owned work; preserve unknown files | Never delete or move user files merely to make the tree conform |
| Optional adapter | Only separately authorized host-required pointers | No external adapter writes by default; no implicit exception |

No other destination is implicitly allowed. Canonical path checks and safe file operations
must enforce this contract; host sandbox permissions remain the security boundary for
arbitrary shell execution. Do not equate the current edit hook with a general filesystem sandbox.

## Consequences

New adoption has a smaller, predictable footprint. Some hosts need explicit task invocation
unless a user requests integration files. Existing root entry files continue to exist until a
separate, reviewed migration accounts for them. Taking an upstream template remains pull-only;
the plugin never maintains an adopter registry or changes another repository out of band.

This records the target contract, not a claim that the current scripts already implement it.
Plans 0011 and 0012 own the remaining implementation and proof. Before release, new adoption,
normal runs, failures and cleanup must be tested against an allowed-write inventory.

---
description: Add a self-contained ai-factory workspace without changing root files
argument-hint: [owner]
allowed-tools: Bash, Read
---
Adopt the current project using the installed plugin. Do not scaffold application code.

1. Run `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/adopt.js" .`.
   If an owner was supplied, pass it as one literal additional argument, never shell program text.
   The script detects declared project commands, copies only ai-factory/, materializes the complete
   agent payload, and records the manifest. If ai-factory/ exists it refuses without overwriting it.
2. Report the created workspace and any commands that could not be detected. No invented checks.
3. Preserve root AGENTS.md, CLAUDE.md, Makefile, Git configuration and tool directories.
   Do not generate external adapters as part of adoption. The default is strict containment.
4. Point to ai-factory/AGENTS.md for explicit invocation and the remaining project context to fill in.
   Do not commit automatically or require a tracker, knowledge source or overlay.

Owner: $ARGUMENTS

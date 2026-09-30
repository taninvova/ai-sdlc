---
description: Add a self-contained ai-factory workspace without changing root files
argument-hint: [owner]
allowed-tools: Bash, Read, Write, Edit
---
Adopt the current project using the installed plugin. Do not scaffold application code.

1. Run `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/adopt.js" .`.
   If an owner was supplied, pass it as one literal additional argument, never shell program text.
   The script detects declared project commands, copies only ai-factory/, materializes the complete
   agent payload, and records the manifest. If ai-factory/ exists it refuses without overwriting it.
   If it refuses or fails, report that and stop — skip every step below.
2. Report the created workspace and any commands that could not be detected. No invented checks.
3. Preserve root AGENTS.md, CLAUDE.md, Makefile, Git configuration and tool directories.
   Do not generate external adapters as part of adoption. The default is strict containment.
4. **Offer, once, an external documentation source — optional, default skip.** Only in an
   interactive session. Ask one question: declare an external documentation source now, or skip?
   Say that the repo's own `ai-factory/docs/` remains the primary knowledge base. On skip, or in a
   headless run, write nothing and ask nothing more. On yes, follow `${CLAUDE_PLUGIN_ROOT}/commands/setup-knowledge.md`
   (its steps 3–7) in this session. Name no product or server yourself.
5. Point to ai-factory/AGENTS.md for explicit invocation and the remaining project context to fill in.
   Do not commit automatically or require a tracker, knowledge source or overlay. If no source
   was declared, add one line: an external documentation source can be added later with
   `/t4:setup-knowledge`.

Owner: $ARGUMENTS

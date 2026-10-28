---
description: Add a self-contained ai-factory workspace without changing root files
argument-hint: [owner]
allowed-tools: Bash, Read, Write, Edit
---
Adopt the current project using the installed plugin. Do not scaffold application code.

1. **Ask for the project name and the artefact prefix.** Every spec, plan, exploration, analysis,
   design, ADR and risk file will be named `<PREFIX>-<NNN>-<slug>.md` (PMB-001, PMB-002…), so
   ask once, before anything is created. Suggest the folder's name as the project name. Then
   suggest a prefix with `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai-factory/make/ids.js" suggest "<name>"`
   (Pembina → PMB). Let the developer accept it or type their own: two to five letters, not AC
   or QC. Say that the prefix is fixed once written. In a headless run, ask nothing; the folder's
   name and its suggested prefix are used.
2. Run `node "${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/scripts/adopt.js" . [owner] --name "<name>" --prefix <PREFIX>`.
   If an owner was supplied, pass it as one literal argument after `.`. Pass the name and prefix
   as literal arguments too, never as shell program text.
   The script detects declared project commands, copies only ai-factory/, writes
   ai-factory/project.json with the name and prefix, materializes the complete
   agent payload, and records the manifest. If ai-factory/ exists it refuses without overwriting it.
   If it refuses or fails, report that and stop — skip every step below.
3. Report the created workspace and its ID prefix and any commands that could not be detected. No invented checks.
4. Preserve root AGENTS.md, CLAUDE.md, Makefile, Git configuration and tool directories.
   Do not generate external adapters as part of adoption. The default is strict containment.
5. **Offer, once, an external documentation source — optional, default skip.** Only in an
   interactive session. Ask one question: declare an external documentation source now, or skip?
   Say that the repo's own `ai-factory/docs/` remains the primary knowledge base. On skip, or in a
   headless run, write nothing and ask nothing more. On yes, follow `${CLAUDE_PLUGIN_ROOT}/commands/setup-knowledge.md`
   (its steps 3–7) in this session. Name no product or server yourself.
6. Point to ai-factory/AGENTS.md for explicit invocation and the remaining project context to fill in.
   Do not commit automatically or require a tracker, knowledge source or overlay. If no source
   was declared, add one line: an external documentation source can be added later with
   `/fc:setup-knowledge`.

Owner: $ARGUMENTS

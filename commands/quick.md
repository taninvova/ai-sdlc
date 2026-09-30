---
description: Make a small, well-understood change with focused verification
argument-hint: <change and expected result>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
---
Model routing comes first. In a repository with `ai-factory/`, run `node ai-factory/make/models.js dispatch --host claude --task quick`
from the repository root before reading the task file, and follow the directive it prints; a
non-zero exit means report its message and stop, doing no task work. When the input begins with
`--task-model=<value>`, remove that option and one `--` after it from the input and add
`--task-model '<value>'` to the dispatch command; never take options from later in the input. If
`ai-factory/make/models.js` is missing, continue unless the workspace's model configuration has a
`routing:` section; then report the template drift, which `/t4:sync-sdlc` inspects, and stop.

Unless the directive routed the task to a worker, read `ai-factory/tasks/quick.md` and follow it with the request below. If the project has no
workspace, report that it needs `/t4:adopt-sdlc`; do not silently create one. If the task file is
missing from an older workspace, report the missing file and `/t4:sync-sdlc` drift inspection.
Do not create external project adapters to make this command work.

If nothing follows the command name, ask for the change and expected result, then stop.

Change: $ARGUMENTS

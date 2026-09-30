---
description: Make a small, well-understood change with focused verification
argument-hint: <change and expected result>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---
Read `ai-factory/tasks/quick.md` and follow it with the request below. If the project has no
workspace, report that it needs `/t4:adopt-sdlc`; do not silently create one. If the task file is
missing from an older workspace, report the missing file and `/t4:sync-sdlc` drift inspection.
Do not create external project adapters to make this command work.

If nothing follows the command name, ask for the change and expected result, then stop.

Change: $ARGUMENTS

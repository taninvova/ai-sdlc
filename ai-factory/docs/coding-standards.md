# Coding standards — ai-sdlc

## Prompts (tasks, agents, skills)
Imperative and specific; name the files to read and the artefact to produce. State what the
task must NOT do — most drift comes from a missing prohibition. Every task ends by reporting
the file path it wrote and what it could not resolve. Keep a task under two pages.
Frontmatter `description:` is what a developer sees in the slash menu — write it for them.

## Smallest complete change
Adapted from Ponytail (MIT, https://github.com/DietrichGebert/ponytail); the same rule adopted
repos receive in their coding standards. Before writing, list every place the change must reach:
callers, copies (templates, agent payloads, Codex skills, docs), checks and fixtures. Then take the
first option that fully works: skip what nobody asked for and name it in the report; reuse an
existing script, helper or check; then Node's stdlib or a shell builtin; otherwise the minimum
code or prose that works. Be lazy about the solution, never about the change: update every copy
and check it breaks. No option, flag or "for later" code nobody asked for; deletion beats
addition. Never cut security, guard behaviour, or a required check. End the report with one line:
what was skipped or not checked, and any risk to know.

## Templates
A change to `skills/ai-layout/templates/` reaches every adopted repo on its next
/fc:adopt-sdlc or /fc:sync-sdlc. Placeholders are `{{name}}`; every one must be substituted or
removed by the adopt command — a leaked `{{…}}` in a real repo is a bug.

## Hook scripts
Node, no dependencies, CommonJS. Never write to stdout; diagnostics go to stderr. Exit 0
unless deliberately blocking (exit 2 with a reason on stderr). Guard every filesystem read
with try/catch and no-op when the layout directory is absent — `aiDir()` decides that, and
until 3.0.0 it accepts the pre-1.0.0 name too, so no script may hard-code either. <!-- path-scan-ok --> Cover behaviour with a fixture under
`skills/ai-hooks/fixtures/`.

## Shell
`set -euo pipefail`, and `shopt -s nullglob` before any loop over a glob that may not match.
Quote every expansion. Generated output must be reproducible — running the script twice in
a row changes nothing.

## Tests
This repo has no test runner. Behaviour is proved by fixtures piped into the hook scripts
and by running the generator in a scratch repo, both recorded in the MR as the before/after
run. A prompt change is proved by a run transcript, not by assertion.

## Dependencies
None. This plugin adds no npm package; anything a hook needs must be in Node's stdlib.

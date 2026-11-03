## Usage

Run it first when something seems wrong with a repo's setup. It runs the plugin's diagnostic script and reports, worst first, the findings and then the unknowns, each finding with the exact command or edit that fixes it. It adds one line on whether the tracker is configured and one on whether an external knowledge source is declared. When nothing is wrong it says so in one line. It is read-only and behaves the same headless.

See also: [Installation: check the setup](../installation.md#3-check-the-setup-fcdoctor), [workflow.md §10](../../ai-factory/docs/workflow.md#10-when-something-is-wrong).

## Examples

```
/fc:doctor
```

## Writes

Nothing. It installs, enables, syncs and edits nothing; every remedy is a command you run.

## Refuses or asks

- It never asks; it only reports.
- An `[unknown]` is not a pass: it says what it would take to answer it.
- It cannot tell you whether the plugin is enabled in a repo where it is not: there the command does not exist, and that absence is the diagnosis (see [workflow.md §10](../../ai-factory/docs/workflow.md#10-when-something-is-wrong)).
- On a layout that predates tracker or knowledge-source support, it names `/fc:sync-sdlc`.

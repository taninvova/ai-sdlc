# FC AI factory: documentation

> For fc ai-sdlc 5.0.1.

The `fc` plugin (repo `ai-sdlc`) is a Claude Code and Codex plugin that adds an operating model for AI-assisted delivery to any repo. It installs one directory, `ai-factory/`, and a set of `/fc:*` commands (`$fc-*` skills on Codex). Each command runs a procedure written in a file you can read and change. Narrow agents (explorer, specifier, planner, tester, implementer, reviewer and others) do the work. They hand off through files on disk, not through chat, so every step can be reviewed, re-run and diffed.

It adds no runtime dependency. Node, Bash, Git and a configured AI CLI are the only prerequisites, and it works with whatever model provider your tool already uses.

For versions and breaking changes, see [CHANGELOG](../CHANGELOG.md).

## Pages

### Getting started

| Page | What it covers |
|---|---|
| [Installation and setup](installation.md) | Install the plugin on Claude Code or Codex, adopt a repo with `/fc:adopt-sdlc`, check it with `/fc:doctor`, keep it current with `/fc:sync-sdlc`. |
| [Choosing a workflow](choosing-a-workflow.md) | How `/fc:start` routes a request: risk before size, then quick, fix, chore, analyse, design, explore or spec. |

### Concepts

| Page | What it covers |
|---|---|
| [How it works](how-it-works.md) | Agents, the file handoff chain, project-prefixed IDs, model routing, and the effort and risk triage. |

### Workflows

| Page | What it covers |
|---|---|
| [Feature](workflows/feature.md) | The full planned path: explore, spec, risk, plan, test, run or loop, review, report. Also `/fc:continue` and `/fc:state`. |
| [Exploration](workflows/exploration.md) | `/fc:explore`: two to four options with a recommendation before any spec. Also `/fc:analyse` and `/fc:design`. |
| [Fix](workflows/fix.md) | `/fc:fix`: reproduce a bug with a failing test, then fix it minimally. |
| [Chore](workflows/chore.md) | `/fc:chore`: small maintenance with no behaviour change. |
| [Quick change](workflows/quick.md) | `/fc:quick`: a small, understood local change with a checklist and a labelled self-review. |

### Reference

| Page | What it covers |
|---|---|
| [Commands](commands.md) | Every `/fc:*` command (25), grouped by purpose, with its arguments, kind and description. Each command's own page says what it writes. |
| [Headless runs and CI](headless-ci.md) | `make -f ai-factory/make/ai.mk` targets, the review gate, `/fc:loop` exit codes, contract gates. |

## Deeper sources

These pages summarise. The full detail lives in:

- [ai-factory/docs/workflow.md](../ai-factory/docs/workflow.md): the complete user guide, with a worked example.
- [README.md](../README.md): the plugin reference (commands, hooks, assurance presets, benchmarks).
- [FACTORY.md](../FACTORY.md): the catalogue entry and the handoff chain.
- [ai-factory/docs/architecture.md](../ai-factory/docs/architecture.md): how the plugin itself is built.

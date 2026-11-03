# ASD-008 — Live /fc:loop view in a Claude Code pane
Created: 2026-11-02T21:07:34.419Z

## Request
Show the live `/fc:loop` view that ASD-007 introduces, with its progress bar and one line per step,
inside Claude Code: in a plugin pane next to the transcript, and optionally as a status-line entry.
It should reuse ASD-007's drawing rather than draw the view a second time. Today ASD-007 shows a
live view only in a second terminal. In a session, `/fc:watch` prints one snapshot, and
`/fc:watch --follow` refuses and points to `make loop-watch` (ASD-007 AC6, AC7). That spec puts
"a Claude Code status line or any other in-session live view" and any file under `.claude/` out
of scope. This request is the follow-up to that exclusion.

## What exists today
- **ASD-007** (`ai-factory/specs/ASD-007-loop-watch.md`, release 6.0.0 after ASD-006's 5.2.0) is
  not built yet; `ai-factory/plans/ASD-007-loop-watch.md` holds only its heading so far. The
  developer asked its planner to make the drawing a pure function: state, plan titles, now and
  `{details, color, width}` in, an array of lines out, with no I/O. The watcher lives in
  `skills/ai-layout/templates/ai-factory/make/loop.js` (AC60), a CommonJS file that requires
  `node:fs`, `node:path`, `node:crypto`, `./safe-files.js` and `./contracts.js` (lines 51–55).
  Plain mode applies when stdout is not a TTY, and its output carries no ANSI (AC49). The spec
  says nothing about where the CLI gets its width in plain mode.
- **Loop state**: `ai-factory/runs/tmp/loop/<loop id>/state.json` (`LOOP_DIR`, loop.js:64). It is
  rewritten in place, so a reader can see a torn read (ASD-007 risk R-list).
- **Plugin shape**: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` list one
  plugin, `fc` 5.1.0. `hooks/hooks.json` holds only command hooks; it has no `modules`. Codex reads
  `.codex-plugin/plugin.json` and `hooks/codex.json`.
  `skills/ai-layout/scripts/check-plugin-hosts.sh` asserts that every Claude hook event has a
  matching Codex handler. Coding standards: hooks are Node, CommonJS, stdlib only; there is no
  build step and no test runner.
- **Claude Code mods** (plugin-authoring `reference.md`, `types/claude-code.d.ts`, examples):
  - A mod is a TS/JS ES module named in `hooks/hooks.json` under `modules`. It runs with no Node
    and reaches everything through `$`. It may `import` only ES-module files of its own plugin.
  - `$.ui.open({id,title})` opens a pane, drawn by `ui.render` `{component:'Pane'}` and sized to
    `e.props.bodyColumns`. A pane the person opened is placed at any width. One opened unasked
    is placed from 144 columns, or 110 once the person has opened that id; below that it waits
    undrawn (`isPlaced:false`). In fullscreen the pane docks beside the transcript; on the main
    screen it shows inline above the prompt.
  - `$.ui.status(text)` pins one line per plugin. `$.clock.every`, `$.fs.read/stat/list` (4 MiB
    cap) and `$.process.run(argv,{env})` (30 s default) are available, plus
    `$.command.register` + `command.run` and `$.state` for draw state.
  - Surfaces: terminal, desktop, vscode, mobile. `claude plugin validate` and `claude plugin test`
    (`*.test.tsx`) need the `claude` CLI. The API is "early access and moves between releases".
- **The mod cannot load loop.js's renderer.** loop.js is CommonJS and needs Node, and the mod has
  neither. The copy that matches a repo's state is that repo's `ai-factory/make/loop.js`, not the
  plugin's template. Reuse therefore means running it: `$.process.run(["node",
  "ai-factory/make/loop.js","watch",id], {env:{COLUMNS}})` in plain mode, once a second while
  `state.json`'s mtime changes or the loop runs. The other ways in are an ESM copy of the
  renderer in the plugin, which would drift, or a reimplementation in TSX.
- **Status line precedent**: ASD-007's exploration, Option B, judged a settings-based status
  line L/XL, because `.claude/` is dont-touch and docs/workspace-boundary.md forbids new external
  entry files.

## Options
**A. A hooks module inside `fc`.** Add `hooks/register.tsx` and `modules` to `hooks/hooks.json`.
On a command, and optionally when a running `state.json` appears, the mod opens pane
`fc-loop`. A clock re-runs `loop.js watch` and draws its lines as `Text`, and `$.ui.status`
carries the bar line. It must no-op without `ai-factory/`. *Changes:* hooks/, a test file,
plugin.json, docs, CHANGELOG, coding-standards.md and architecture.md (a TS module in a
Node/CommonJS plugin). *Effort XL:* size XL, because it needs an ADR to break "hooks are
CommonJS, no build"; uncertainty L, because the pattern and API are new. *Risks:* every adopter's
Claude sessions load a module from an early-access API. `claude plugin test` is not in the bash
check suite. There is a command-name clash with `commands/watch.md`. A `modules` key next to
`hooks` is unverified. *Later:* easiest path to on-by-default. Codex gets nothing, and
the parity check must learn to ignore modules.

**B. A companion mod plugin (for example `fc-watch`), opt-in.** This is the same mechanism as A,
shipped as its own plugin folder and marketplace entry, with its own version, and it calls
`fc`'s `loop.js watch` as a contract. `fc` keeps its standards and stays Codex-symmetric. *Changes:*
a new plugin folder (manifest, `hooks/hooks.json`, `register.tsx`, test), one
`marketplace.json` entry, docs. It changes no template if ASD-007's plain mode already reads
width from `COLUMNS`. *Effort L:* size L, because it is a new artefact; uncertainty L, because
the API is new and placement is unverified. *Risks:* version skew with a repo's `loop.js`, which
must be answered as "/fc:sync-sdlc", as AC8 does. A developer has to install it. *Later:* it can be
folded into `fc` (A) once the API settles. It is removed by uninstalling it.

**C. Host status line only, no mod.** Document a user-level `statusLine` command such as
`node ai-factory/make/loop.js watch --line`. `fc` writes nothing under `.claude/`. *Changes:*
`loop.js` gains a one-line form, which is a template change and breaking, plus docs.
*Effort M:* size M; uncertainty M, because the statusline refresh timing and its stdin are
host-defined. *Risks:* it is not a pane, so step lines are lost; it refreshes per host event and
is not live while subagents run (ASD-007 exploration B); there is a setup step per developer.
*Later:* independent of A and B.

**D. Guidance only.** Document a split beside the chat: tmux `split-window`, a VS Code or iTerm
split, or the desktop terminal, each running `make -f ai-factory/make/ai.mk loop-watch
FOLLOW=1`. *Changes:* `docs/commands/_notes/watch.md` and `loop.md`. *Effort S:* size S;
uncertainty S. *Risks:* none new. It works for Codex too. It is not in-app, and mobile and
desktop gain nothing.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A in-plugin mod | XL | high (all adopters, early-access API, standards change) | medium | no — needs ADR | no |
| B companion mod | L | medium (contained, opt-in) | high (uninstall) | yes, beside it; leaves `fc` unchanged | **yes** |
| C status line | M | medium (template change, not live) | high | partly (setup outside `ai-factory/`) | no |
| D guidance | S | low | high | yes | as a stop-gap, in ASD-007 docs |

## Recommendation
**B** (opinion). It gives the pane and status entry the request asks for and reuses ASD-007's
drawing by running `loop.js watch` in plain mode. That keeps one renderer and needs no ESM copy.
It also keeps `fc`'s Node/CommonJS/no-build rules, its Codex parity check and every adopted
repo untouched while the mods API is early access. Ask ASD-007's planner now to take the
plain-mode width from `COLUMNS` (or `--width`). The pane then needs no `fc` template change after
6.0.0. *What would change my mind:* if the developer wants the pane on for everyone without an
install, choose A with an ADR. If `claude plugin test` cannot run where checks run, start with D.

### Effort and risk
Effort **L**: size L, because a new plugin artefact with a test and a marketplace entry is more
than 5 files; uncertainty L, because the mods API is a new pattern and placement and auto-open
are unverified.
- Uncertain requirements: **present**. The request leaves open auto-open versus command-only,
  colour, `--details`, and the status text.
- Authorization: **absent**. It reads local loop state and runs the repo's own `loop.js`.
- Public contracts: **present**. A new plugin and command are added, and it depends on
  `loop.js watch`'s plain output and width input.
- Migrations: **absent**. It writes no state and adds no schema.
- Dependencies: **present**. It depends on Claude Code's early-access mods API and on the `claude`
  CLI for validate and test.
- Service ownership: **absent**. The plugin is in the same repo with the same owner.

Present triggers: uncertain requirements, public contracts, dependencies. Run `/fc:risk` once the
spec exists.

## Open questions
1. Should the pane open on its own when a `/fc:loop` starts, which needs 144 columns or 110 after
   the first open, or only on a command? If it is a command, is it `/fc-watch:pane` or a change to
   ASD-007 AC7 so that `/fc:watch --follow` opens the pane?
2. Should the companion live in this repo, as a second marketplace entry, or in its own repo? Does
   it need an ADR or a `/fc:design` pass?
3. Is plain, uncoloured text acceptable in the pane? Colour needs a structured output from
   `loop.js`, such as `--json` lines with styles, which is a template change.
4. What should the status entry hold? For example, the bar line `ASD-004 ▰▰▰▱▱ 3/5 · 2 running`,
   and should it clear when the loop ends?
5. If several loops run, which one does the pane show? ASD-007's default selection, or a picker?
6. Can `claude plugin validate/test` run in this repo's CI, or is a recorded run the proof?
7. Should the `loop.js` width input (`COLUMNS` or `--width`) land in ASD-007 (6.0.0) or in this
   feature?

## Next
`/fc:spec ai-factory/explorations/ASD-008-loop-watch-pane.md option B`

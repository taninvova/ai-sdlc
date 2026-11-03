# ASD-002 — Interactive presentation of the AI factory
Created: 2026-10-29T21:44:04.293Z

## 1. Request
Produce an interactive presentation of the ai-sdlc plugin (the "AI factory"). It should cover
how the factory works (agents handing off through files in `ai-factory/`), how to install it and
adopt a repo, the workflows for a feature (`/fc:explore → /fc:spec → … → /fc:review`), a chore,
a fix and an exploration, and a reference for every `/fc:*` command. It must have clickable
diagrams. The model is the dmtools documentation site. The deliverable is for people
evaluating or adopting the plugin. It is not a change to the templates adopted repos receive.

## 2. What exists today
- **No docs site, no generated docs, no diagrams.** The repo has no `docs/` site, no HTML, and
  no Mermaid block in any markdown file (`grep -c mermaid` is 0 across `README.md`, `FACTORY.md`
  and `ai-factory/docs/*`). There is no CI workflow, so nothing is hosted. The remote is
  `github.com` (GitHub).
- **Content sources:** `ai-factory/docs/workflow.md` (958 lines). §1 is install, §2 adopting a repo,
  §3 "Which command do I want?" (a text decision tree), §4 the main loop with a worked CSV
  example, §5 every command, §6 headless/CI. `FACTORY.md` has the handoff-chain table
  (phase · role · agent · command · reads · writes). `README.md` has the command list.
  `ai-factory/tasks/start.md` holds the routing rules (risk before size; quick/fix/chore/analyse/
  design/explore/spec). `fix.md`, `chore.md` and `quick.md` hold the short-path procedures.
- **Machine-readable command data:** each `skills/ai-layout/templates/ai-factory/tasks/*.md` (18
  files) has `description:` and `argument-hint:` frontmatter. `agents/*.md` have `name:`/`description:`.
- **Precedent for generating from frontmatter:** `skills/ai-layout/scripts/sync-claude-commands.js`
  reads task frontmatter and writes `commands/*.md` (25 files). It has a `--check` mode that fails
  on stale output. `sync-codex-skills.js` follows the same pattern. Every `check-*.sh` there runs
  through `make check`.
- **Drift already exists in hand-copied facts.** `README.md:29` says 25 commands.
  `workflow.md:108` says 22 commands with 16 project tasks, and `workflow.md:140` says 25.
- **Constraints:** `coding-standards.md` says "Dependencies: None. This plugin adds no npm
  package". `AGENTS.md` says "no build step". Anything under `skills/ai-layout/templates/`
  ships to every adopted repo.
- **The example (fetched 2026-10-29).** Both the docs and the landing page are built with
  **Astro** (`/_astro/*.css`, `astro-code` Shiki highlighting with a `github-dark-default`
  theme). The **docs** page has a top bar with GitHub and "Docs source" links. The footer
  reads "Rendered from" the repo's `dmtools-ai-docs` folder. It has a left sidebar of 10 groups
  (Overview, Installation, Configuration, MCP tools, Jobs, Agents, Workflows, Test generation,
  Reporting, Skill packages), breadcrumbs, an "On this page" TOC and an "All 67 pages" index
  with one-line descriptions. A dark/light theme is saved in localStorage. The fetched page
  showed no rendered diagrams. The **landing page** (`/`) has the interactive part, an
  "Example agent pipeline": agent nodes are `<button>`s placed absolutely by phase
  (`data-agent-id`, `data-phase-index`), with descriptions in their labels. It also has
  terminal-style command snippets, reveal-on-scroll sections and a FAQ. I could not see whether
  any page renders Mermaid. "Mermaid" appears only as the name of an MCP tool page.

## 3. Options
**A — Static docs site from the repo's markdown (VitePress, Docusaurus or MkDocs Material) + Mermaid.**
Add a `site/` directory with the generator config. It renders `README.md`, `FACTORY.md` and
`workflow.md` split into pages, with Mermaid flowcharts for the main loop, the decision tree and
the short paths. Add a GitHub Pages CI job. This comes closest to the dmtools *docs* layout
(sidebar, search, TOC). *Effort XL:* it breaks the no-dependency standard, so it needs an ADR,
and it needs new CI. *Risks:* npm or Python toolchain upkeep, and the command reference is still
prose copied from workflow.md, so it can drift. Diagrams are drawn by hand in Mermaid. Mermaid
nodes can link to pages, but click-to-explain is limited. *Later:* adding pages is easy. Keeping
counts and commands correct stays hard.

**B — One self-contained interactive HTML presentation, written by hand.**
Add one `presentation/index.html` with vendored reveal.js, or plain HTML/CSS/JS. Slides cover
install, how it works, feature/chore/fix/explore, and commands. Diagrams are inline SVG or HTML
nodes. Clicking a node opens its command, its inputs and outputs, and its rule. This matches
the dmtools *landing* pipeline. *Effort L:* a new artefact, built on a known pattern. *Risks:*
everything is copied by hand, so it goes stale on the next release, as the 22-versus-25 count
already has. Vendoring reveal.js adds a third-party file. *Later:* easy to present offline and
to email. Each release needs a manual update that no check enforces.

**C — Generator in the repo, using only the Node standard library, that writes one self-contained interactive HTML.**
Add `skills/ai-layout/scripts/build-presentation.js`, modelled on `sync-claude-commands.js`. It
reads the task frontmatter (and `agents/*.md`) for the command reference and the counts. It
also reads one hand-written narrative and diagram file, for example `presentation/source.json`
or `.md`, that defines the slides and the diagram nodes (each node keyed to a task name).
From these it writes one HTML file with inline CSS, inline SVG and button-node diagrams, plus
a small inline script for slide navigation and node details. It also adds
`check-presentation.sh`, which runs the generator with `--check` and fails if the output is
stale, or if a diagram node names a task that does not exist or any task is missing. *Effort L:*
size L (a new artefact and a new check), uncertainty M (the layout is a known pattern, the
visual design is not). *Risks:* hand-built SVG diagrams take more care to author than Mermaid.
The narrative prose can still drift, though commands and counts cannot. *Later:* the
presentation can be hosted on GitHub Pages or opened from a file. It could later become the data
source for option A.

## 4. Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A Docs site + Mermaid | XL | M: toolchain, drift | Medium: CI and config to remove | No: needs a dependency ADR | Later, if a full portal is wanted |
| B Hand-written HTML deck | L | H: stale on next release | High: delete one file | Partly: no check, copied facts | No |
| C Generated HTML + check | L | L–M: diagram authoring | High: delete script and output | Yes: same pattern as sync-claude-commands.js, no dependency | **Yes** |

## 5. Recommendation
**Option C** *(opinion)*. Of the three, only C gives what was asked (interactive diagrams,
commands, workflows, offline or hosted) while keeping the plugin's no-dependency rule and
including a check that stops the command reference from drifting. Drift has already happened
in this repo's prose. The dmtools pattern worth copying is the *landing page's* clickable
pipeline of agent nodes, and C can build that without Astro. The docs sidebar layout is not
required for a presentation. *What would change my mind:* if the developer wants a multi-page,
searchable docs portal like dmtools `/docs/`, choose A and write the ADR. If this is a one-off
talk for a single date, choose B.

### Effort and risk
Effort **L**: size L (a new script, a new check and a new output artefact), uncertainty M.
- Uncertain requirements: **present**. The audience, hosting, slide deck versus docs portal,
  and where the output lives are not stated.
- Authorization: **absent**. A static, read-only page with no login or data.
- Public contracts: **absent**. It reads task frontmatter and changes no command, task or template.
- Migrations: **absent**. No data or layout moves.
- Dependencies: **absent**. Node standard library only, with no CDN, npm or vendored library.
- Service ownership: **absent**. One repo and no service boundary.

Present: uncertain requirements. Run `/fc:risk` once the spec exists.

## 6. Open questions
1. Who is the audience and how will they view it: a live talk (slide mode), self-serve reading
   (scrolling page), or both?
2. Hosting: GitHub Pages (needs a workflow under `.github/workflows/`, which does not exist yet),
   the file committed and opened locally, or a link from `README.md`?
3. Where should the output and source live: a new top-level `presentation/` folder, or somewhere
   else? It must stay out of `skills/ai-layout/templates/` so it does not ship to adopted repos.
4. Should the presentation include `/fc:analyse`, `/fc:design`, `/fc:loop`, `/fc:continue`,
   contracts and headless CI, or only feature/chore/fix/explore plus install?
5. Branding: should it use the dmtools visual style (dark theme, Sora/JetBrains Mono)?
   Web fonts would be an external fetch unless they are dropped or embedded.

## 7. Next
`/fc:spec Interactive presentation of the AI factory, option C from ai-factory/explorations/ASD-002-interactive-presentation.md: a Node-stdlib generator in skills/ai-layout/scripts/ that builds one self-contained HTML (install, how it works, feature/chore/fix/explore workflows as clickable diagrams, command reference from task frontmatter) plus a check-presentation.sh --check that fails on drift`

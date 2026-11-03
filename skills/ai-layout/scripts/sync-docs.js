#!/usr/bin/env node
// Generates the user command reference (ASD-003): docs/commands.md and one
// docs/commands/<name>.md per commands/<name>.md, with the hand-kept notes in
// docs/commands/_notes/<name>.md merged in verbatim and the group table taken from
// docs/commands/_notes/_groups.md. Frontmatter is read only through ./_frontmatter.js.
// A write run then prunes orphan pages: only regular *.md files directly in docs/commands/ with
// no commands/<name>.md; never recursive, never _notes/, never another file type.
// --check writes nothing: it reports every stale or missing generated file, orphan page, missing
// notes file, missing or empty required notes heading and ungrouped command, every broken relative
// link, #fragment or Mermaid `click` target in docs/ (and in README.md links into docs/), every
// link that resolves outside the repository, and a wrong docs/README.md version line; then exits 1.
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const readFrontmatter = require("./_frontmatter.js");

const root = path.resolve(__dirname, "../../..");
const SELF = "skills/ai-layout/scripts/sync-docs.js";
const TASKS = "skills/ai-layout/templates/ai-factory/tasks";
const NOTES = "docs/commands/_notes";
const check = process.argv.includes("--check");

const abs = (rel) => path.join(root, rel);
const readText = (rel) => fs.readFileSync(abs(rel), "utf8").replace(/\r\n/g, "\n");
const listMd = (rel) =>
	fs.existsSync(abs(rel))
		? fs
				.readdirSync(abs(rel), { withFileTypes: true })
				.filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
				.map((entry) => entry.name.slice(0, -3))
				.sort()
		: [];

const failures = [];
const fail = (message) => failures.push(message);
// A problem the write run can only warn about is a failure under --check.
const warnOrFail = (message) => (check ? fail(message) : console.error(`${SELF}: ${message}`));

let count = 0;
// What each generated file will hold: `body` for anchors and existence, `own` (the body minus the
// hand content carried in from _notes/) for link checking, so a notes link is reported once, as
// the notes file's.
const rendered = new Map();
function emit(rel, body, own = body) {
	count++;
	rendered.set(rel, { body, own });
	const current = fs.existsSync(abs(rel)) ? fs.readFileSync(abs(rel), "utf8") : null;
	if (check) {
		if (current === null) fail(`${rel} is missing; run node ${SELF}`);
		else if (current !== body) fail(`${rel} is stale; run node ${SELF}`);
		return;
	}
	fs.mkdirSync(path.dirname(abs(rel)), { recursive: true });
	if (current !== body) fs.writeFileSync(abs(rel), body);
}

// ---- notes structure -----------------------------------------------------------------------
// A heading counts only as an H2 line exactly `## <name>`; its content runs to the next `## `
// line or the end of the file, and whitespace alone is empty.
const REQUIRED = ["Usage", "Examples", "Writes", "Refuses or asks"];
const requiredFor = (name) => (name === "check" ? ["Usage"] : REQUIRED);
function checkNotes(rel, name, text) {
	const lines = text.split("\n");
	for (const heading of requiredFor(name)) {
		const at = lines.findIndex((l) => l.replace(/\s+$/, "") === `## ${heading}`);
		if (at < 0) {
			fail(`${rel} has no "## ${heading}" heading`);
			continue;
		}
		const next = lines.findIndex((l, i) => i > at && l.startsWith("## "));
		const body = lines.slice(at + 1, next < 0 ? lines.length : next).join("\n");
		if (!body.trim()) fail(`${rel} has an empty "## ${heading}" section`);
	}
}

// A table cell: one line, pipes escaped so a hint such as `a|b` stays in its cell.
const cell = (text) => String(text).replace(/\s*\n\s*/g, " ").replace(/\|/g, "\\|");
const code = (text) => `\`${cell(text)}\``;
// Prose in a cell: angle brackets escaped so `--spec <id>` is shown, not parsed as an HTML tag.
const prose = (text) => cell(text).replace(/</g, "&lt;").replace(/>/g, "&gt;");

// ---- commands ------------------------------------------------------------------------------
const tasks = new Set(listMd(TASKS));
const commands = listMd("commands").map((name) => {
	const fm = readFrontmatter(readText(`commands/${name}.md`));
	const project = tasks.has(name);
	const taskFm = project ? readFrontmatter(readText(`${TASKS}/${name}.md`)) : {};
	const description = fm.description || taskFm.description || "";
	if (!description) throw new Error(`commands/${name}.md has no description in its frontmatter`);
	const hint = fm["argument-hint"] || (project ? taskFm["argument-hint"] : "") || "";
	const deprecatedFor = /^Deprecated — use \/fc:([a-z0-9-]+)\b/.exec(description)?.[1] || null;
	return { name, description, hint, project, deprecatedFor };
});
const byName = new Map(commands.map((c) => [c.name, c]));
const kind = (c) => (c.project ? "Project task" : "Plugin-level command");
const args = (c) => (c.hint ? code(c.hint) : "none");

// ---- one page per command ------------------------------------------------------------------
for (const c of commands) {
	const notesRel = `${NOTES}/${c.name}.md`;
	const hasNotes = fs.existsSync(abs(notesRel));
	const notes = hasNotes ? readText(notesRel).trim() : "";
	if (!hasNotes) warnOrFail(`command ${c.name} has no notes file ${notesRel}`);
	else {
		if (check) checkNotes(notesRel, c.name, readText(notesRel));
		if (!notes) console.error(`${SELF}: ${notesRel} is empty; the page has no notes`);
	}
	const kindCell = c.project
		? `${kind(c)} — loads \`ai-factory/tasks/${c.name}.md\` from your repo, so it needs an adopted workspace`
		: `${kind(c)} — works in any repo`;
	const lines = [
		`# /fc:${c.name}`,
		"",
		"[← Back to commands](../commands.md)",
		"",
		`<!-- Generated by ${SELF} from commands/${c.name}.md; do not edit. Edit ${notesRel} instead. -->`,
		"",
	];
	if (c.deprecatedFor)
		lines.push(`> **Deprecated.** Use [\`/fc:${c.deprecatedFor}\`](${c.deprecatedFor}.md) instead.`, "");
	lines.push(
		"| Field | Value |",
		"|---|---|",
		`| Claude name | \`/fc:${c.name}\` |`,
		`| Codex name | \`$fc-${c.name}\` |`,
		`| Kind | ${cell(kindCell)} |`,
		`| Description | ${prose(c.description)} |`,
		`| Arguments | ${args(c)} |`,
		"",
	);
	const own = lines.join("\n");
	if (notes) lines.push(notes, "");
	emit(`docs/commands/${c.name}.md`, lines.join("\n"), own);
}

// ---- index ---------------------------------------------------------------------------------
const groupsRel = `${NOTES}/_groups.md`;
const groupsText = fs.existsSync(abs(groupsRel)) ? readText(groupsRel) : "";
if (!groupsText) warnOrFail(`${groupsRel} is missing; docs/commands.md lists every command under one table`);
// The group table, minus its leading authoring comment, is hand content carried into the index.
const groupTable = groupsText.replace(/^\s*<!--[\s\S]*?-->\s*/, "").trim();
const groups = [];
for (const row of groupTable.split("\n")) {
	const cells = row.trim().replace(/^\||\|$/g, "").split("|").map((s) => s.trim());
	if (cells.length < 2 || /^-+$/.test(cells[0]) || /^group$/i.test(cells[0])) continue;
	const title = /^\[([^\]]+)\]/.exec(cells[0])?.[1] || cells[0];
	const members = [...cells.slice(1).join("|").matchAll(/`([a-z0-9-]+)`/g)].map((m) => m[1]);
	groups.push({ title, members });
}
const grouped = new Set();
for (const g of groups)
	for (const name of g.members) {
		if (!byName.has(name)) console.error(`${SELF}: ${groupsRel} lists ${name}, which has no commands/${name}.md`);
		grouped.add(name);
	}
const ungrouped = commands.filter((c) => !grouped.has(c.name));
if (ungrouped.length && (groups.length || check))
	warnOrFail(`in no group of ${groupsRel}: ${ungrouped.map((c) => c.name).join(", ")}`);

const projectCount = commands.filter((c) => c.project).length;
const index = [
	"# Commands",
	"",
	"[← Back to index](README.md)",
	"",
	`<!-- Generated by ${SELF}; do not edit. Edit ${groupsRel} for the groups and ${NOTES}/<name>.md for each page. -->`,
	"",
	`The plugin ships **${commands.length}** \`/fc:*\` commands on Claude Code. Codex has a matching \`$fc-<name>\` skill for each (\`/fc:spec\` → \`$fc-spec\`). The ${projectCount} project tasks load \`ai-factory/tasks/<name>.md\` from your repo, so they need an adopted workspace; the other ${commands.length - projectCount} are plugin-level and work in any repo.`,
	"",
	"Descriptions and arguments come from the frontmatter of `commands/*.md` and, for a project task without an argument hint of its own, its task template. `<…>` is required, `[…]` optional. Each command links to its help page.",
	"",
];
const sections = [];
const section = (title, members) => {
	sections.push(`## ${title}`, "", "| Command | Arguments | Kind | Description |", "|---|---|---|---|");
	for (const c of members)
		sections.push(`| [\`/fc:${c.name}\`](commands/${c.name}.md) | ${args(c)} | ${kind(c)} | ${prose(c.description)} |`);
	sections.push("");
};
for (const g of groups) {
	const members = g.members.filter((name) => byName.has(name)).map((name) => byName.get(name));
	if (members.length) section(g.title, members);
}
if (ungrouped.length) section(groups.length ? "Other commands" : "All commands", ungrouped);
emit(
	"docs/commands.md",
	[...index, ...(groupTable ? [groupTable, ""] : []), ...sections].join("\n"),
	[...index, ...sections].join("\n"),
);

// ---- orphan pages --------------------------------------------------------------------------
// Only regular *.md files directly in docs/commands/: no recursion, so _notes/ is never entered,
// and a directory or symlink named like a page is not a regular file.
const PAGES = "docs/commands";
const orphans = fs.existsSync(abs(PAGES))
	? fs
			.readdirSync(abs(PAGES), { withFileTypes: true })
			.filter((entry) => entry.isFile() && entry.name.endsWith(".md") && !byName.has(entry.name.slice(0, -3)))
			.map((entry) => `${PAGES}/${entry.name}`)
			.sort()
	: [];
for (const rel of orphans) {
	if (check) fail(`${rel} is an orphan page: there is no commands/${path.basename(rel)}; run node ${SELF} to delete it`);
	else {
		fs.unlinkSync(abs(rel));
		console.error(`${SELF}: deleted orphan page ${rel}`);
	}
}

// ---- links, anchors and Mermaid click targets (--check only) -------------------------------
// Scans every regular *.md under docs/ and the root README.md's links into docs/. A notes file
// docs/commands/_notes/<name>.md is checked as rendered in docs/commands/<name>.md, and _groups.md
// as rendered in docs/commands.md; a generated file is checked as it will be written, not as it
// stands on disk (a stale copy is already reported above).
const toRel = (file) => path.relative(root, file).split(path.sep).join("/");
const inside = (file) => {
	const rel = path.relative(root, file);
	return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
};
// After a lexical check, an existing target must also stay inside once symlinks are resolved.
const realRoot = (() => {
	try {
		return fs.realpathSync(root);
	} catch {
		return root;
	}
})();
const insideReal = (file) => {
	try {
		const rel = path.relative(realRoot, fs.realpathSync(file));
		return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
	} catch {
		return true;
	}
};
const pageExists = (rel) => rendered.has(rel) || fs.existsSync(abs(rel));
const pageText = (rel) => {
	if (rendered.has(rel)) return rendered.get(rel).body;
	try {
		return fs.readFileSync(abs(rel), "utf8").replace(/\r\n/g, "\n");
	} catch {
		return "";
	}
};

// Fenced code blocks are blanked (line count kept), except that a Mermaid block's `click` lines
// are collected as targets; inline code spans and HTML comments (which the host does not render)
// are masked so a `[x](y)` inside one is no link.
function scanText(text) {
	const lines = text.split("\n");
	const clicks = [];
	let fence = null;
	for (let i = 0; i < lines.length; i++) {
		const l = lines[i];
		if (fence) {
			const close = /^ {0,3}(`{3,}|~{3,})\s*$/.exec(l);
			if (close && close[1][0] === fence.char && close[1].length >= fence.len) fence = null;
			else if (fence.mermaid) {
				const click = /^\s*click\s+\S+\s+(?:href\s+)?"([^"]*)"/.exec(l);
				if (click) clicks.push({ target: click[1], line: i + 1 });
			}
			lines[i] = "";
			continue;
		}
		const open = /^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)/.exec(l);
		if (open) {
			fence = { char: open[1][0], len: open[1].length, mermaid: open[2].toLowerCase() === "mermaid" };
			lines[i] = "";
		}
	}
	const mask = (m) => m.replace(/[^\n]/g, "x");
	const prose = lines
		.join("\n")
		.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g, mask)
		.replace(/<!--[\s\S]*?(?:-->|$)/g, mask);
	return { prose, clicks, lines };
}

// GitLab heading anchors, by the rule the plan states: heading text lowercased; every character
// that is not a letter, a digit, a space, `-` or `_` dropped; spaces become `-`; a repeated slug
// gets -1, -2, … in order. Markdown link and HTML syntax is reduced to its text first.
function slug(heading) {
	return heading
		.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1")
		.replace(/<[^>]*>/g, "")
		.toLowerCase()
		.replace(/[^\p{L}\p{N} _-]/gu, "")
		.replace(/ /g, "-");
}
const anchorCache = new Map();
function anchors(rel) {
	if (anchorCache.has(rel)) return anchorCache.get(rel);
	const out = new Set();
	const seen = new Map();
	for (const l of scanText(pageText(rel)).lines) {
		const h = /^ {0,3}#{1,6}(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$/.exec(l);
		if (!h) continue;
		const base = slug(h[1] || "");
		const n = seen.get(base) || 0;
		seen.set(base, n + 1);
		out.add(n ? `${base}-${n}` : base);
	}
	anchorCache.set(rel, out);
	return out;
}

// One target from page `label`, resolved against `baseDir` (repo-relative); `self` is the page
// whose headings a bare #fragment refers to. Returns a failure message or null.
function checkTarget(label, kindOf, raw, baseDir, self, onlyDocs = false) {
	let target = raw.trim().replace(/^<(.*)>$/, "$1");
	if (!target || /^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith("//")) return null;
	const hash = target.indexOf("#");
	let file = hash < 0 ? target : target.slice(0, hash);
	const fragment = hash < 0 ? "" : target.slice(hash + 1);
	try {
		file = decodeURIComponent(file);
	} catch {}
	let resolved = self;
	if (file) {
		const full = file.startsWith("/") ? path.join(root, file) : path.resolve(abs(baseDir), file);
		if (onlyDocs) {
			const r = toRel(full);
			if (!inside(full) || !(r === "docs" || r.startsWith("docs/"))) return null;
		}
		if (!inside(full)) return `${label}: ${kindOf} ${raw} resolves outside the repository (${full})`;
		resolved = toRel(full);
		if (!pageExists(resolved)) return `${label}: ${kindOf} ${raw} points to ${resolved}, which does not exist`;
		if (!rendered.has(resolved) && !insideReal(full))
			return `${label}: ${kindOf} ${raw} resolves outside the repository through a symlink`;
	}
	if (!fragment || !resolved.endsWith(".md")) return null;
	let id = fragment;
	try {
		id = decodeURIComponent(fragment);
	} catch {}
	if (!anchors(resolved).has(id)) return `${label}: ${kindOf} ${raw} has no heading anchor #${id} in ${resolved}`;
	return null;
}

const LINK = /!?\[(?:[^[\]]|\[[^[\]]*\])*\]\(\s*(<[^>\n]*>|[^\s)]+)(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*\)/g;
const REFDEF = /^ {0,3}\[(?!\^)[^\]]+\]:[ \t]*(<[^>\n]*>|\S+)/gm;
function checkPage({ label, text, baseDir, self, onlyDocs = false }) {
	const { prose, clicks } = scanText(text);
	const lineAt = (index) => prose.slice(0, index).split("\n").length;
	const found = [];
	for (const re of [LINK, REFDEF]) for (const m of prose.matchAll(re)) found.push({ target: m[1], line: lineAt(m.index), kindOf: "link" });
	if (!onlyDocs) for (const c of clicks) found.push({ ...c, kindOf: "Mermaid click target" });
	for (const f of found) {
		const message = checkTarget(`${label}:${f.line}`, f.kindOf, f.target, baseDir, self, onlyDocs);
		if (message) fail(message);
	}
}

function walkMd(rel, out = []) {
	let entries = [];
	try {
		entries = fs.readdirSync(abs(rel), { withFileTypes: true });
	} catch {
		return out;
	}
	for (const e of entries.sort((a, b) => a.name.localeCompare(b.name))) {
		const child = `${rel}/${e.name}`;
		if (e.isDirectory()) walkMd(child, out);
		else if (e.isFile() && e.name.endsWith(".md")) out.push(child);
	}
	return out;
}

if (check) {
	const pages = new Set([...walkMd("docs"), ...rendered.keys()]);
	for (const rel of [...pages].sort()) {
		const notesMatch = new RegExp(`^${NOTES}/([^/]+)\\.md$`).exec(rel);
		if (rendered.has(rel)) {
			checkPage({ label: rel, text: rendered.get(rel).own, baseDir: path.posix.dirname(rel), self: rel });
		} else if (notesMatch) {
			// Notes are content of a generated page: resolve their links from that page.
			const page = notesMatch[1] === "_groups" ? "docs/commands.md" : `docs/commands/${notesMatch[1]}.md`;
			const self = rendered.has(page) ? page : rel;
			checkPage({ label: `${rel} (rendered in ${page})`, text: readText(rel), baseDir: path.posix.dirname(page), self });
		} else checkPage({ label: rel, text: readText(rel), baseDir: path.posix.dirname(rel), self: rel });
	}
	if (fs.existsSync(abs("README.md")))
		checkPage({ label: "README.md", text: readText("README.md"), baseDir: ".", self: "README.md", onlyDocs: true });

	// ---- docs/README.md version line ---------------------------------------------------------
	let version = null;
	try {
		version = JSON.parse(readText(".claude-plugin/plugin.json")).version || null;
	} catch {}
	if (!version) fail(".claude-plugin/plugin.json has no readable version; cannot check the docs/README.md version line");
	else {
		const expected = `> For fc ai-sdlc ${version}.`;
		const lines = fs.existsSync(abs("docs/README.md")) ? readText("docs/README.md").split("\n") : null;
		if (!lines) fail(`docs/README.md is missing; expected line 3 "${expected}" (version ${version} from .claude-plugin/plugin.json)`);
		else if (lines.length < 3 || lines[2] === "" && lines.length === 3)
			fail(`docs/README.md has no line 3; expected "${expected}" (version ${version} from .claude-plugin/plugin.json)`);
		else {
			const m = /^> For fc ai-sdlc (\S+)\.$/.exec(lines[2]);
			if (!m) fail(`docs/README.md line 3 is "${lines[2]}", not the version line; expected "${expected}" (version ${version} from .claude-plugin/plugin.json)`);
			else if (m[1] !== version)
				fail(`docs/README.md line 3 names version ${m[1]}; expected ${version} from .claude-plugin/plugin.json ("${expected}")`);
		}
	}
}

if (check) {
	for (const message of failures) console.error(`${SELF} --check: ${message}`);
	if (failures.length) {
		console.error(`${SELF} --check: ${failures.length} failure(s); nothing was written`);
		process.exit(1);
	}
	console.log(`User command docs current: ${count}`);
} else console.log(`User command docs generated: ${count}`);

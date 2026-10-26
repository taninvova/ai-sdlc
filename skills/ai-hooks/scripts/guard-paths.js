#!/usr/bin/env node
const {
	readEvent,
	aiDir,
	loopWorktree,
	WORKTREES,
	canonicalTarget,
	fs,
	path,
} = require("./_common");

const EMPTY_POLICY = "<!-- t4:allow-empty-policy -->";
const hasControl = (value) =>
	Array.from(value).some((character) => character.charCodeAt(0) < 32);
function parseRules(text) {
	const rules = [];
	let explicitEmpty = false;
	for (const [index, line] of text.split(/\r?\n/).entries()) {
		if (line.trim() === EMPTY_POLICY) explicitEmpty = true;
		if (!/^\s*[-*+]\s/.test(line)) continue;
		const match = /^- `([^`]+)`(?:\s+[^`]*|\s*)$/.exec(line);
		const rule = match?.[1];
		if (
			!rule ||
			rule.trim() !== rule ||
			path.isAbsolute(rule) ||
			hasControl(rule) ||
			/[\\*?[\]{}]/.test(rule) ||
			rule
				.replace(/\/$/, "")
				.split("/")
				.some((part) => !part || part === "." || part === "..")
		) {
			throw new Error(
				`invalid path-prefix rule on line ${index + 1}; use - \`relative/prefix\``,
			);
		}
		rules.push(rule);
	}
	if (explicitEmpty && rules.length)
		throw new Error("empty-policy marker conflicts with path rules");
	if (!rules.length && !explicitEmpty) {
		throw new Error(
			`no valid rules; add path rules or ${EMPTY_POLICY} for an intentionally empty policy`,
		);
	}
	return rules;
}

function matches(target, rule) {
	return (
		target.startsWith(rule) ||
		(!rule.includes("/") && path.basename(target).startsWith(rule))
	);
}

try {
	const ev = readEvent();
	// Inside a /t4:loop worktree, paths are judged against the main repository and its policy:
	// the worktree's own dont-touch.md is a copy an implementer could edit.
	const loop = loopWorktree(ev);
	const ai = loop ? loop.ai : aiDir(ev);
	if (!ai) process.exit(0);
	const policy = `${path.basename(ai)}/docs/dont-touch.md`;
	const targets = require("./_edit-targets").editTargets(ev);
	if (
		!targets.length ||
		targets.some(
			(target) => typeof target !== "string" || !target || hasControl(target),
		)
	) {
		throw new Error(
			"guarded mutation has no valid target path; supply file_path, path or notebook_path",
		);
	}
	let rules;
	try {
		rules = parseRules(
			fs.readFileSync(path.join(ai, "docs", "dont-touch.md"), "utf8"),
		);
	} catch (error) {
		throw new Error(
			`${policy}: ${error.code || error.message}; restore a readable, valid policy`,
		);
	}
	const root = loop ? loop.root : path.dirname(ai);
	const cwd = fs.realpathSync(ev.cwd || process.cwd());
	// A path inside <layout>/runs/tmp/worktrees/<name>/, where <name> is a registered worktree
	// (its .git is a file), is judged relative to that worktree's root (AC35). Anything else under
	// runs/, including the worktrees directory itself and a stray directory there, keeps the main
	// rules (AC36). The lexical and the canonical path are scoped separately, so `..` and symlinks
	// that leave the worktree are judged where they really land.
	const prefix = [path.basename(ai), ...WORKTREES].join("/") + "/";
	function scope(absolute) {
		const relative = path.relative(root, absolute).split(path.sep).join("/");
		if (!relative.startsWith(prefix)) return { base: root, relative };
		const rest = relative.slice(prefix.length);
		const slash = rest.indexOf("/");
		if (slash <= 0 || slash === rest.length - 1) return { base: root, relative };
		const base = path.join(root, ...prefix.split("/").filter(Boolean), rest.slice(0, slash));
		try {
			if (!fs.lstatSync(path.join(base, ".git")).isFile())
				return { base: root, relative };
		} catch (error) {
			if (error.code !== "ENOENT") throw error;
			return { base: root, relative };
		}
		return { base, relative: rest.slice(slash + 1) };
	}
	for (const target of targets) {
		const canonical = canonicalTarget(cwd, target);
		const lexical = scope(path.resolve(cwd, target));
		const real = scope(canonical);
		const hit = rules.find((rule) => {
			if (matches(lexical.relative, rule) || matches(real.relative, rule))
				return true;
			const rulePath = canonicalTarget(real.base, rule);
			return (
				canonical === rulePath ||
				canonical.startsWith(rulePath + (rule.endsWith("/") ? path.sep : ""))
			);
		});
		if (hit) {
			process.stderr.write(
				`Blocked by ${policy}: target matches rule "${hit}". Choose another path or ask the developer.\n`,
			);
			process.exit(2);
		}
	}
} catch (error) {
	process.stderr.write(`Blocked by path guard: ${error.message}.\n`);
	process.exit(2);
}

#!/usr/bin/env node
const { readEvent, aiDir, canonicalTarget, fs, path } = require("./_common");

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
	const ai = aiDir(ev);
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
	const root = path.dirname(ai);
	const cwd = fs.realpathSync(ev.cwd || process.cwd());
	for (const target of targets) {
		const canonical = canonicalTarget(cwd, target);
		const lexical = path
			.relative(root, path.resolve(cwd, target))
			.split(path.sep)
			.join("/");
		const relative = path.relative(root, canonical).split(path.sep).join("/");
		const hit = rules.find((rule) => {
			if (matches(lexical, rule) || matches(relative, rule)) return true;
			const rulePath = canonicalTarget(root, rule);
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

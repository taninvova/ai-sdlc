// Shared frontmatter reader (ASD-003). Takes the text of a markdown file and returns the keys of
// its frontmatter block as strings: only the block between the first two `---` lines, and only
// when the file opens with one. A `key: value` line elsewhere in the file is never read.
// Node built-ins only, no top-level side effects, writes nothing.
"use strict";

function readFrontmatter(text) {
	const lines = String(text).replace(/^﻿/, "").split(/\r?\n/);
	const out = {};
	if (lines[0] !== "---") return out;
	const end = lines.indexOf("---", 1);
	if (end < 0) return out;
	for (const line of lines.slice(1, end)) {
		const match = /^([A-Za-z0-9_-]+):(?:\s+(.*))?$/.exec(line);
		if (match) out[match[1]] = (match[2] || "").trim();
	}
	return out;
}

module.exports = readFrontmatter;

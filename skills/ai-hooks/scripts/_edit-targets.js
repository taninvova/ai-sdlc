// Both hosts reach the same policy check; Codex sends the whole patch in command.
function editTargets(event) {
	if (event.tool_name === "apply_patch") {
		const patch = event.tool_input?.command;
		if (typeof patch !== "string")
			throw new Error("apply_patch has no patch command");
		const lines = patch.trim().split(/\r?\n/);
		if (lines.shift() !== "*** Begin Patch" || lines.pop() !== "*** End Patch")
			throw new Error("apply_patch has invalid patch boundaries");
		const targets = [];
		for (const line of lines) {
			const match =
				/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/.exec(
					line,
				);
			if (match) targets.push(match[1]);
			else if (line.startsWith("*** ") && line !== "*** End of File")
				throw new Error("apply_patch has an unknown file directive");
		}
		if (!targets.length) throw new Error("apply_patch has no target path");
		return [...new Set(targets)];
	}
	const target =
		event.tool_input?.file_path ??
		event.tool_input?.path ??
		event.tool_input?.notebook_path;
	return target === undefined ? [] : [target];
}
module.exports = { editTargets };

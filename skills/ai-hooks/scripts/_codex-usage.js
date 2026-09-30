const fs = require("node:fs");
const { createHash } = require("node:crypto");

// Rollout formats are host-version-specific. Prefer per-response records; older
// Codex rollouts expose cumulative token_count snapshots instead. Never sum both.
function sumCodexTranscript(file, claim) {
	const result = { turns: 0, inp: 0, out: 0, cr: 0, cw: 0, model: "" };
	let body;
	try {
		body = fs.readFileSync(file, "utf8");
	} catch {
		return result;
	}
	const records = [];
	for (const line of body.split("\n")) {
		try {
			const record = JSON.parse(line);
			if (
				record &&
				["turn_context", "token_usage_record", "event_msg"].includes(
					record.type,
				)
			)
				records.push(record);
		} catch {}
	}
	const modern = records.some(
		(r) => r.type === "token_usage_record" && r.payload?.usage,
	);
	const previous = {
		input_tokens: 0,
		cached_input_tokens: 0,
		output_tokens: 0,
		cache_write_input_tokens: 0,
	};
	for (const record of records) {
		if (record.type === "turn_context" && record.payload?.model)
			result.model = record.payload.model;
		let usage, identity;
		if (modern) {
			if (record.type !== "token_usage_record" || !record.payload?.usage)
				continue;
			usage = record.payload.usage;
			identity =
				typeof record.payload.response_id === "string" &&
				record.payload.response_id
					? record.payload.response_id
					: JSON.stringify(record);
		} else {
			if (record.type !== "event_msg" || record.payload?.type !== "token_count")
				continue;
			const total = record.payload.info?.total_token_usage;
			if (!total) continue;
			const reset = Object.keys(previous).some(
				(key) => (total[key] ?? 0) < previous[key],
			);
			usage = {};
			for (const key of Object.keys(previous)) {
				usage[key] = (total[key] ?? 0) - (reset ? 0 : previous[key]);
				previous[key] = total[key] ?? 0;
			}
			identity = JSON.stringify(record);
		}
		const values = [
			usage.input_tokens ?? 0,
			usage.cached_input_tokens ?? 0,
			usage.output_tokens ?? 0,
			usage.cache_write_input_tokens ?? 0,
		];
		if (
			!values.every((n) => Number.isFinite(n) && n >= 0) ||
			values.every((n) => n === 0)
		)
			continue;
		const key =
			"u:codex-" + createHash("sha256").update(identity).digest("hex");
		if (claim && !claim.add(key)) continue;
		result.turns++;
		result.inp += Math.max(0, values[0] - values[1]);
		result.cr += values[1];
		result.out += values[2];
		result.cw += values[3];
	}
	return result;
}
module.exports = { sumCodexTranscript };

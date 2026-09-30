// Hook-side lifecycle adapter. It links the usage a hook has just counted to the lifecycle event
// stream, and records the session binding that `lifecycle.js start` prints. Best effort by
// contract: a failure here is one stderr line, never a failed hook, never a changed run-log row.
// Opt-in: nothing happens unless ai-factory/contracts/config.json sets lifecycle.enabled.
const { boundary } = require("./_safe-files");
const store = require("./_lifecycle-events")({ boundary });

function enabled(ai) {
	try {
		return store.config(ai).enabled;
	} catch (error) {
		process.stderr.write(`Lifecycle config ignored: ${error.message}\n`);
		return false;
	}
}
const host = (ev) => (ev.host === "codex" ? "codex" : "claude");
const session = (ev) => (store.PATTERNS.session_id.test(String(ev.session_id || "")) ? ev.session_id : null);
// A headless parent passes its run down; nothing else is trusted as an attribution.
const inheritedRun = () => (store.PATTERNS.run_id.test(process.env.T4_LIFECYCLE_RUN || "") ? process.env.T4_LIFECYCLE_RUN : null);
// The cost cell the row writer produced: "~0.0123" is an estimate at built-in rates, "0.0123" an
// estimate at models.yaml rates, "" unknown. Unknown stays null; it is never read as zero.
function cost(cell) {
	const text = String(cell ?? "");
	if (!text) return { cost_usd: null, cost_provenance: null };
	const value = Number(text.replace(/^~/, ""));
	if (!Number.isFinite(value)) return { cost_usd: null, cost_provenance: null };
	return { cost_usd: value, cost_provenance: text.startsWith("~") ? "estimated:built-in-rates" : "estimated:models.yaml" };
}
function linkUsage(ai, ev, { source, agent, model, sum, costCell, extraClaims = [] }) {
	if (!enabled(ai)) return;
	try {
		const claimed = [...extraClaims, ...(sum.claimed || [])];
		// Unique source records identify the usage; without any, it cannot be de-duplicated and says so.
		const key = claimed.length ? store.recordKey(claimed) : store.recordKey([`unclaimed:${host(ev)}:${session(ev)}:${source}:${Date.now()}:${Math.random()}`]);
		store.emit(ai, {
			event_id: store.hashId("usage", key),
			type: "usage_linked",
			host: host(ev),
			session_id: session(ev),
			run_id: inheritedRun(),
			usage: {
				source,
				agent: agent ? String(agent).slice(0, 60) : null,
				model: model ? String(model).slice(0, 100) : null,
				turns: sum.turns,
				input_tokens: sum.inp,
				output_tokens: sum.out,
				cache_read_tokens: sum.cr,
				cache_write_tokens: sum.cw,
				...cost(costCell),
				record_key: key,
				dedupable: claimed.length > 0,
				claimed_records: claimed.length,
				first_at: sum.first_at || null,
				last_at: sum.last_at || null,
			},
		});
	} catch (error) {
		process.stderr.write(`Lifecycle event not recorded: ${error.message}\n`);
	}
}
// PostToolUse on a shell command: `lifecycle.js start` prints the run it opened. Binding that run
// to this session is an explicit signal; a session is never bound by guessing.
function bindSession(ai, ev) {
	const command = String(ev.tool_input?.command || "");
	if (!/lifecycle\.js["']?\s+start\b/.test(command)) return;
	if (!enabled(ai)) return;
	try {
		const output = JSON.stringify(ev.tool_response ?? ev.tool_output ?? "");
		const match = /started run (r-[0-9a-f]{16})/.exec(output);
		const id = session(ev);
		if (!match || !id) return;
		store.emit(ai, { event_id: store.hashId("bind", id, match[1]), type: "session_bound", host: host(ev), session_id: id, run_id: match[1] });
	} catch (error) {
		process.stderr.write(`Lifecycle event not recorded: ${error.message}\n`);
	}
}
module.exports = { linkUsage, bindSession, enabled };

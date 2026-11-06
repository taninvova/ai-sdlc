#!/usr/bin/env node
require("./_common").runHook(() => {
	// One row per concluded subagent, from that agent's OWN transcript.
	//
	// The point of the event is attribution: a session that delegates a step to an agent spends most
	// of its tokens inside that agent, and a Stop row alone cannot say which agent spent them. So this
	// writes a `source=agent` row carrying the agent's name in the `agent` column, beside the `tool`
	// column rather than inside it — `claude,implementer`, not `claude/implementer`.
	//
	// The parent `transcript_path` is never opened. Every field comes from the payload, from
	// `agent_transcript_path`, or from `cwd` — so an unreadable or absent parent transcript costs this
	// row nothing, and the event adds exactly one transcript read to the turn.
	const { readEvent, logDir, task } = require("./_common");
	const { claims, withUsageLog, appendUsageRow } = require("./_usage");
	const ev = readEvent();
	const ai = logDir(ev);
	if (!ai) return;
	const cwd = ev.cwd || process.cwd();
	if (!ev.agent_transcript_path) return;

	return withUsageLog(ai, (safe) => {
		// The session's claim ledger, shared with the session rows: one file per `session_id` holding
		// `u:<message uuid>` for a counted usage record and `a:<agent id>` for a concluded agent. Sharing
		// it is what makes a record copied into an agent transcript count once across BOTH kinds of row —
		// context inheritance re-logs a prefix of the parent's records into each fork child, and a naive
		// per-transcript sum counts those tokens once per transcript that carries them.
		const taskName = task(ai, ev.session_id);
		const ledger = claims(ai, ev.session_id);

		// A resumed agent fires SubagentStop again, the second time with `stop_hook_active: true`. Claiming
		// the agent id is what makes the second event a no-op, so the agent gets one row and its tokens are
		// counted once. Claimed before the sum, not after the append: two subagents concluding at once must
		// not lose each other's claims to a read-modify-write (the same trade-off session-stop.js takes).
		if (ev.agent_id && !ledger.add("a:" + ev.agent_id)) return;

		// That transcript only, and subject to the uuid rule. A missing, unreadable or unparseable file
		// sums to nothing, which is the same no-row exit as a transcript carrying no usage at all.
		// `task` is the session's, not the agent's: a specifier spawned under /fc:run is `run,specifier`.
		// `agent` is the payload's agent_type verbatim.
		appendUsageRow({
			ai,
			ev,
			safe,
			ledger,
			transcript: ev.agent_transcript_path,
			source: "agent",
			agent: ev.agent_type || "",
			taskName,
			cwd,
			extraClaims: ev.agent_id ? ["a:" + ev.agent_id] : [],
		});
	});
});

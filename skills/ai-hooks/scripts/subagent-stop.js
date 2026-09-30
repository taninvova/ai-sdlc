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
	const {
		readEvent,
		aiDir,
		user,
		branch,
		task,
		fs,
		path,
	} = require("./_common");
	const { claims, sumTranscript, price } = require("./_usage");
	const ev = readEvent();
	const ai = aiDir(ev);
	if (!ai) return;
	const cwd = ev.cwd || process.cwd();
	if (!ev.agent_transcript_path) return;

	return require("./_common").withLogLock(ai, (safe) => {
		for (const name of ["log.pending.csv", "log.previous.csv"])
			safe.assertPath(path.join(ai, "runs", name));
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
		const { turns, inp, out, cr, cw, model } = sumTranscript(
			ev.agent_transcript_path,
			ledger,
		);
		if (turns === 0) return;

		const { rate, approx } = price(ai, model);
		const cost =
			(inp * rate.input +
				out * rate.output +
				cr * rate.cache_read +
				cw * rate.cache_write) /
			1e6;
		const hit = (cr / (inp + cr + cw || 1)).toFixed(2);

		// Into log.pending.csv, never straight into the committed log.csv — log-flush.js moves the rows
		// when the session commits, so the log changes only inside the commit that produced the work.
		const { ensureSchema, csv } = require("./_log-schema");
		const file = path.join(ai, "runs", "log.pending.csv");
		try {
			ensureSchema(file);
			safe.append(
				file,
				[
					new Date().toISOString(),
					ev.session_id,
					"agent",
					user(cwd),
					branch(cwd),
					// `task` is the session's, not the agent's: attribution follows the `/t4:` command the session
					// is running, so a specifier spawned under /t4:run is `run,specifier` and never a static
					// agent→task map. Empty when the session has run no command. `agent` is the payload's
					// agent_type verbatim, and `tool` still carries `claude` alone, unsplit and unqualified.
					taskName,
					"claude",
					ev.agent_type || "",
					model,
					turns,
					inp,
					out,
					cr,
					cw,
					hit,
					approx + cost.toFixed(4),
					"",
				]
					.map(csv)
					.join(",") + "\n",
			);
		} catch (error) {
			throw error;
		}
	});
});

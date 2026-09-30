#!/usr/bin/env node
require("./_common").runHook(() => {
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
	if (!ev.transcript_path || !fs.existsSync(ev.transcript_path)) return;

	return require("./_common").withLogLock(ai, (safe) => {
		for (const name of ["log.pending.csv", "log.previous.csv"])
			safe.assertPath(path.join(ai, "runs", name));
		// The session's claim ledger, shared with the subagent rows so a record copied into an agent
		// transcript is counted once across the two kinds of row. Claims are both recorded and ENFORCED:
		// only records this session has not already counted are summed, so the row below is the increment
		// since this session's previous row rather than a re-sum of the whole transcript, and the rows of
		// one session_id sum to what the session actually spent. The first Stop has claimed nothing yet,
		// so its increment is the whole transcript so far and nothing is lost at the start.
		//
		// A record carrying no `uuid` cannot be claimed, so it is counted by every Stop — an over-count on
		// a transcript format that omits the key, never a silent loss (_usage.js says the same).
		//
		// Deliberately claim-before-write, not claim-after-append: two concluding subagents must not lose
		// each other's claims to a read-modify-write, so the claim lands as the sum walks the file. The
		// cost is that an append failure below is diagnosed but leaves those records claimed with no row carrying
		// them, and later deltas will not re-report them.
		const taskName = task(ai, ev.session_id);
		const ledger = claims(ai, ev.session_id);
		const { turns, inp, out, cr, cw, model } = sumTranscript(
			ev.transcript_path,
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

		// Rows go to log.pending.csv, which is gitignored, not to the committed log.csv. A Stop fires
		// after every turn, so writing straight into a tracked file kept it dirty for the whole session
		// and refused every `git checkout`. log-flush.js moves the rows into log.csv when the session
		// commits, so the log changes only inside the commit that produced the work.
		const { ensureSchema, csv } = require("./_log-schema");
		const file = path.join(ai, "runs", "log.pending.csv");
		try {
			ensureSchema(file);
			safe.append(
				file,
				[
					new Date().toISOString(),
					ev.session_id,
					"session",
					user(cwd),
					branch(cwd),
					// `task` is the `/t4:` command this session last ran, from the file log-task.js writes, and
					// empty when it ran none. `agent` is empty on a session row: the subagent rows carry their own
					// name.
					taskName,
					"claude",
					"",
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

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { boundary, withLogLock } = require("./_safe-files");

function readEvent() {
	try {
		return JSON.parse(fs.readFileSync(0, "utf8"));
	} catch {
		return {};
	}
}
// The layout directory, by name, newest first. 1.0.0 renamed `ai/` to `ai-factory/`. A repo that
// has taken the plugin update and not yet run /t4:migrate-layout still carries the old name, and
// must keep its dont-touch guard and its run log until it does — a rename that silently disarmed
// the guard would look like nothing was wrong. Transitional, but not until 2.0.0: dropping it is
// itself a silent break for any repo that never migrated (ADR 0008).
const LAYOUT_DIRS = ["ai-factory", "ai"];
function repositoryRoot(cwd) {
	const start = fs.realpathSync(cwd);
	let dir = start;
	for (;;) {
		try {
			// A worktree's .git is a file. Never walk past either kind of boundary.
			fs.lstatSync(path.join(dir, ".git"));
			return dir;
		} catch (error) {
			if (error.code !== "ENOENT") throw error;
		}
		const parent = path.dirname(dir);
		if (parent === dir) return start; // Legacy non-Git adoption is cwd-local.
		dir = parent;
	}
}
function aiDir(ev) {
	const root = repositoryRoot(ev.cwd || process.cwd());
	for (const name of LAYOUT_DIRS) {
		const dir = path.join(root, name);
		try {
			fs.lstatSync(dir); // Broken symlinks are invalid adoption, not an absent layout.
			return dir;
		} catch (error) {
			if (error.code !== "ENOENT") throw error;
		}
	}
	return null;
}
// A /t4:loop worktree lives at <main>/<layout>/runs/tmp/worktrees/<name>. Inside one, the main
// repository is found through the git common dir, so its run log and its dont-touch policy
// govern; every other checkout, including a developer's own worktree, keeps its own. Returns
// { root, ai, name } for the main repository, or null. Git runs only for a cwd on that path.
const WORKTREES = ["runs", "tmp", "worktrees"];
function loopWorktree(ev) {
	try {
		const root = repositoryRoot(ev.cwd || process.cwd());
		const parts = root.split(path.sep);
		const at = parts.findIndex(
			(part, i) =>
				LAYOUT_DIRS.includes(part) &&
				WORKTREES.every((name, j) => parts[i + 1 + j] === name),
		);
		if (at < 0) return null;
		const common = git(["rev-parse", "--git-common-dir"], root);
		if (!common) return null;
		const gitDir = fs.realpathSync(path.resolve(root, common));
		if (path.basename(gitDir) !== ".git") return null;
		const main = path.dirname(gitDir);
		for (const name of LAYOUT_DIRS) {
			const ai = path.join(main, name);
			const relative = path.relative(path.join(ai, ...WORKTREES), root);
			if (
				!relative ||
				relative.startsWith("..") ||
				path.isAbsolute(relative) ||
				relative.includes(path.sep)
			)
				continue;
			fs.lstatSync(ai);
			return { root: main, ai, name: relative };
		}
	} catch {}
	return null;
}
// Where run-log rows, task markers, claims and lifecycle events go: the main repository's
// layout directory inside a loop worktree, the checkout's own everywhere else (AC37).
function logDir(ev) {
	const loop = loopWorktree(ev);
	return loop ? loop.ai : aiDir(ev);
}

// Resolve each existing component before handling '..', just as the filesystem does.
// Missing leaves are allowed; broken links, loops and inaccessible ancestors are not.
function canonicalTarget(cwd, target) {
	const absolute = path.isAbsolute(target)
		? target
		: `${cwd}${path.sep}${target}`;
	let resolved = path.parse(absolute).root;
	for (const part of absolute.slice(resolved.length).split(path.sep)) {
		if (!part || part === ".") continue;
		if (part === "..") {
			resolved = path.dirname(resolved);
			continue;
		}
		const candidate = path.join(resolved, part);
		try {
			fs.lstatSync(candidate);
		} catch (error) {
			if (error.code !== "ENOENT") throw error;
			resolved = candidate;
			continue;
		}
		resolved = fs.realpathSync(candidate);
	}
	return resolved;
}
function git(args, cwd) {
	try {
		return execFileSync("git", args, {
			cwd,
			stdio: ["ignore", "pipe", "ignore"],
		})
			.toString()
			.trim();
	} catch {
		return "";
	}
}
function user(cwd) {
	return (
		process.env.GITLAB_USER || git(["config", "user.name"], cwd) || "unknown"
	);
}
function branch(cwd) {
	return git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);
}
function identifier(value) {
	const id =
		value === undefined || value === null || value === "" ? "unknown" : value;
	if (
		typeof id !== "string" ||
		!/^[A-Za-z0-9_-][A-Za-z0-9_.:-]{0,199}$/.test(id)
	)
		throw new Error("Unsafe event identifier");
	return id;
}
function runHook(action) {
	try {
		action();
	} catch (error) {
		process.stderr.write(`Hook write declined: ${error.message}\n`);
	}
}
function appendJsonl(file, obj) {
	const safe = boundary(path.dirname(path.dirname(file)));
	safe.mkdir(path.dirname(file));
	safe.append(file, JSON.stringify(obj) + "\n");
}
// The task this session is running, as log-task.js last saw it: one line, keyed by session_id,
// beside the run log. No file means the session has typed no `/t4:` command, and the column stays
// empty — a task is never inferred from the branch name, the agent type or the prompt text, because
// a wrong attribution is worse than a missing one. First line only, so a file somehow holding more
// cannot widen a row.
function task(ai, sessionId) {
	try {
		const file = path.join(ai, "runs", ".task." + identifier(sessionId));
		boundary(ai).assertPath(file);
		return fs.readFileSync(file, "utf8").split("\n")[0].trim();
	} catch (error) {
		if (error.code === "ENOENT") return "";
		throw error;
	}
}
module.exports = {
	readEvent,
	aiDir,
	logDir,
	loopWorktree,
	WORKTREES,
	repositoryRoot,
	canonicalTarget,
	git,
	user,
	branch,
	task,
	appendJsonl,
	identifier,
	runHook,
	withLogLock,
	boundary,
	fs,
	path,
};

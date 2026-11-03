## Usage

**Deprecated.** Use [`/fc:review`](review.md) instead. `/fc:check` is the old name of `/fc:review`.
It tells you once, in one line, that it is deprecated, then runs the same review task with the same
input. It takes the same arguments and writes what `/fc:review` writes: nothing, only the JSON
verdict. Headless, `TASK=check` also still runs the review task and says so on stderr.

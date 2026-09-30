---
description: Review the selected change, including uncommitted work by default
argument-hint: [working-tree|branch|supplied diff and context]
---
Delegate to the `reviewer` subagent. Default to the working tree: include staged and unstaged
changes plus relevant nonignored untracked files, without staging anything or reading ignored
secrets. If an explicit branch scope or supplied diff is given, honor that scope; never replace
supplied input with another diff. Review against the named spec/plan or the request's acceptance
checklist for a small change. Report exactly one JSON object using the reviewer's schema, with
scope, reviewed paths and any assessment in summary. Add no prose outside that object.
Do not fix files or change the index. An in-session review is a self-check, not an independent opinion.

Context: $ARGUMENTS

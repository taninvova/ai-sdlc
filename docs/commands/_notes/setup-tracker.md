## Usage

Optional. Run it when you want `/fc:spec ABC-12` to draft from a ticket. It follows `ai-factory/docs/tracker.md`, the only place that knows what a tracker is and what counts as configured: it detects the reachable site, shows it to you and asks before writing. Then it asks whether to commit the configuration or keep it for yourself, and proves it by resolving one key you give it. An optional site URL is passed along as context for that detection; the site it shows you is still the one it found reachable.

It only reads the tracker: it never comments on, creates or moves anything there.

See also: [Installation: optional integrations](../installation.md#5-optional-integrations), [workflow.md §2](../../ai-factory/docs/workflow.md#2-set-a-repo-up-once-per-repo).

## Examples

```
/fc:setup-tracker
/fc:setup-tracker https://jira.example.com
```

## Writes

`ai-factory/jira.yaml`, after you confirm, with only the keys `tracker.md` defines as required. If you choose to keep it out of Git, it also adds that path to `ai-factory/.gitignore` and says the repo is now configured for you alone.

## Refuses or asks

- Stops before reading or writing if `ai-factory/docs/tracker.md` is missing: the layout predates tracker support, and `/fc:sync-sdlc` reports it as an upstream file to take.
- Stops in a non-interactive session: it never writes from assumed answers.
- Writes nothing if no site is reachable, and names what would fix it.
- Asks a second time before replacing an existing configuration, after showing its contents.
- Asks whether to commit or ignore the file, and asks for one key to prove it; with none, it reports the configuration as unverified.

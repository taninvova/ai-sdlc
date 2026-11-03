## Usage

Use it when the request is still a business description rather than a buildable feature: several actors, permissions, business rules, a lifecycle, integrations, or policy nobody has decided yet. It settles **what** the business needs, before any spec. The `analyst` agent writes a requirements pack (objectives, scope, actors and permissions, use cases, requirements, rules, data, stories with acceptance criteria, test scenarios) and labels every statement a supplied fact, confirmed decision, assumption, proposal or open question.

The first word picks the mode:

| Input | Mode |
|---|---|
| `<feature description>` | `document`: the full pack |
| `lean <feature description>` | objectives, scope, essential requirements, rules, acceptance criteria and open decisions only |
| `questions <feature description>` | up to five consequential questions and no pack |
| `review <analysis path>` | omissions, contradictions and gaps in an existing pack, with proposed corrections |
| `update <analysis path> <change>` | change control on an existing pack: every affected item updated together, version bumped |
| `explain <analysis path>` | a plain-language stakeholder summary that keeps every uncertainty |

It ends with the file path, readiness in one sentence, the questions that block a spec and the `/fc:spec …` line to run once they are answered. A small, well-understood change goes straight to `/fc:spec`; where a capability lives is `/fc:design`; how to build it is `/fc:explore`.

See also: [Exploration workflow: analyse](../workflows/exploration.md#analyse-settle-what-is-needed), [workflow.md §3](../../ai-factory/docs/workflow.md#3-which-command-do-i-want).

## Examples

```
/fc:analyse Partners submit refund requests; team leads approve up to 500 EUR, finance above that
/fc:analyse lean Customers can pause a subscription for up to three months
/fc:analyse review ai-factory/analyses/PMB-004-refund-approval.md
/fc:analyse update ai-factory/analyses/PMB-004-refund-approval.md Finance now approves above 1000 EUR
```

## Writes

- `document` and `lean`: one new `ai-factory/analyses/<ID>-<slug>.md`, created by the ID helper.
- `update`: the existing pack it names, in place.
- `review`: nothing; its findings and proposed corrections are in the report.
- `questions` and `explain`: no new pack (they never call the ID helper).

Never specs, plans, designs, ADRs or code, and nothing outside the repo.

## Refuses or asks

- With no input, asks which feature to analyse (who uses it, what they should do, why it matters), and stops. It never takes one from the branch name or the last commit.
- Asks at most five questions in its report; the rest stay in the pack as open questions.
- With no ID prefix in the project yet, asks for the project name and a prefix interactively; headless, writes nothing and reports why.
- Invents no policy, estimate, approval, compliance requirement or existing architecture; such gaps stay open questions.

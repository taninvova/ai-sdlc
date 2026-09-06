# Changelog

## 0.2.0 — 2026-09-06
- Renamed from ai-base and split: Next.js pieces moved to the nextjs-scaffold plugin; NestJS lives in nestjs-scaffold.
- New `/investigate` command + task: 2–4 implementation options with trade-offs before a spec; output in `ai/investigations/`.
- New `/init` command: add the ai/ layout to an existing repo without a framework scaffold.
- `/ai-sync` renamed `/sync`; guards against repos without `ai/`.
- Generic templates are framework-neutral with `{{…_extra}}` slots overlays fill.

## 0.1.2 / 0.1.1 / 0.1.0 — 2026-09-05 (as ai-base)
- Initial layout, hooks, reviewer; skills hidden from the slash menu; sync guard.

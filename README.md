# Agent Skills

Skills for AI coding agents (Claude Code and compatible tools). Each
directory is one skill: a `SKILL.md` whose frontmatter `description` tells
the agent when to load it, and whose body is the working knowledge — verified
behavior, gotchas, and patterns that correct an agent's wrong-by-default
assumptions before they're exercised.

## Skills

- **[inaturalist](inaturalist/SKILL.md)** — the iNaturalist API (v1/v2):
  field selection, observation field values, drift-immune pagination, and
  geoprivacy/trusted-access semantics as actually observed live, not as
  commonly assumed.

## Install

Copy (or symlink) a skill's directory into your agent's skills directory —
for Claude Code:

```bash
git clone https://github.com/rainhead/skills
ln -s "$PWD/skills/inaturalist" ~/.claude/skills/inaturalist
```

## Maintenance

Each skill states facts plainly and cites authoritative sources — inline for
load-bearing claims, and in a closing Sources section for verification and
deeper reading. Dated verification receipts — what was checked, when,
against what — live in the skill's `CHANGES.md`. Corrections welcome — these
documents exist to be less wrong than an agent's priors. Maintained with the
help of AI agents. 🤖

## License

[CC0 1.0](LICENSE) — public domain. No attribution required.

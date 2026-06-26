# Crescendo Agent Template

A multi-agent orchestration framework for [Antigravity](https://github.com/google-deepmind/antigravity).

Crescendo scales AI development horizontally — a Coordinator Agent dispatches parallel Subagents, each isolated in its own git worktree, then merges their work through automated quality gates and contradiction detection.

## Quick Start

```bash
# 1. Clone the template
gh repo create my-project --template <your-org>/crescendo-agent-template --private --clone
cd my-project

# 2. Verify infrastructure
python conductor/bin/preflight_check.py

# 3. Drop project files
cp ~/my-prd.md input/
just sanitize-inputs

# 4. Start the Crescendo
# Tell the AI: "Initialize the Crescendo workflow using the engineering profile."
```

## Prerequisites

| Tool | Required | Install |
|------|----------|--------|
| git | ✅ | [git-scm.com](https://git-scm.com) |
| Python 3.10+ | ✅ | [python.org](https://python.org) |
| just | ✅ | [just.systems](https://just.systems/man/en/installation.html) |
| gh (GitHub CLI) | Optional | [cli.github.com](https://cli.github.com) |

## Domain Profiles

| Profile | Domain | Roles | Autonomy |
|---------|--------|-------|----------|
| `engineering.json` | Software | 6 | Full |
| `legal.json` | Legal Analysis | 9 | Checkpoint |
| `marketing.json` | Marketing | 8 | Full |
| `research.json` | Research | 11 | Full |
| `localization.json` | i18n/L10n | 16 | Full |

## Structure

```
├── GEMINI.md              # 36 behavioral directives for the Coordinator
├── justfile               # Automation commands
├── input/                 # Drop project files here
├── .agents/skills/        # 9 packaged skills (auto-discovered)
├── .worktrees/            # Agent workspaces (created at runtime)
└── conductor/             # Orchestration brain
    ├── bin/               # 9 scripts (gates, state, validation, preflight)
    ├── profiles/          # 5 domain configurations
    ├── schemas/           # Claims JSON schema
    ├── templates/         # Setup templates (style guides)
    └── workflow.md        # Execution protocols
```

## Documentation

- [GEMINI.md](GEMINI.md) — Coordinator directives
- [conductor/workflow.md](conductor/workflow.md) — Execution protocols
- [conductor/profiles/](conductor/profiles/) — Domain configurations

## License

Proprietary — IrongatePropertyCollective

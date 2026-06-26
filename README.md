# Crescendo

**A multi-agent orchestration framework for [Antigravity](https://github.com/google-deepmind/antigravity).**

Crescendo scales AI work horizontally across any domain. The Coordinator Agent (**Maestro**) dispatches parallel Subagents — each isolated in its own workspace, each focused on a specific role — then merges their work through automated quality gates and contradiction detection. A dedicated Scribe Agent (**Score**) runs alongside, maintaining a forensic log. The same orchestration engine powers software engineering, legal analysis, marketing campaigns, academic research, and localization.

> 📖 **For the full guide, architecture details, and AI ingestion instructions, see [CRESCENDO.md](CRESCENDO.md).**

---

## Quick Start

### 1. Clone the Template

```bash
gh repo create my-project --template <your-org>/crescendo-agent-template --private --clone
cd my-project
```

### 2. Verify Infrastructure

```bash
# Windows
just preflight

# macOS / Linux
python3 conductor/bin/preflight_check.py
```

This checks: external tools, core files, conductor scripts (9/9), domain profiles, and packaged skills (9/9). Fix any ❌ items before proceeding.

### 3. Drop Project Files

Place your project requirements in the `input/` folder at the project root:

```
my-project/
├── input/                    ← Drop files here
│   ├── my-prd.md             # Product requirements
│   ├── architecture.png      # System diagrams
│   └── constraints.md        # Regulatory/compliance rules
└── ...
```

Then sanitize them:

```bash
just sanitize-inputs
```

> **Note:** Binary files (PDF, DOCX, XLSX) require manual review — they cannot be auto-sanitized.

### 4. Start Maestro

Open **Antigravity** and set this project as the active workspace. Then type:

> *"Start the Crescendo workflow."*

Maestro will:
1. Prompt you to **select a domain profile** (engineering, legal, marketing, research, or localization)
2. Parse your sanitized inputs
3. Break the work into tracks and tasks
4. Present a **pre-flight briefing** for your approval (agent count, quota estimate, commit scope, autonomy level)
5. Dispatch Score (Scribe) and domain agents in parallel phases once you approve

### 5. Monitor & Resume

```bash
just git-status-condutree    # View all agent worktrees
```

If the run pauses due to quota limits, start a new session and type: *"Resume Crescendo run."* Maestro reads `orchestration_state.json` and picks up where it stopped.

---

## Prerequisites

| Tool | Required | Install | Notes |
|------|----------|---------|-------|
| git | ✅ | [git-scm.com](https://git-scm.com) | |
| Python 3.10+ | ✅ | [python.org](https://python.org) | Runs conductor scripts |
| just | ✅ | [just.systems](https://just.systems/man/en/installation.html) | Task runner |
| Antigravity | ✅ | [Google Antigravity](https://github.com/google-deepmind/antigravity) | AI orchestration platform |
| gh (GitHub CLI) | Optional | [cli.github.com](https://cli.github.com) | Needed for HITL via GitHub Issues |

---

## Domain Profiles

| Profile | Domain | Roles | Autonomy | Aggregation | Data Classification |
|---------|--------|-------|----------|-------------|-------------------|
| `engineering.json` | Software Engineering | 6 | Full | git_merge | internal |
| `legal.json` | Legal Analysis | 9 | Checkpoint | document_assembly | confidential |
| `marketing.json` | Marketing/Content | 8 | Full | editorial_merge | public |
| `research.json` | Academic Research | 11 | Full | matrix_assembly | internal |
| `localization.json` | Internationalization | 16 | Full | matrix_assembly | internal |

Maestro can also **create new roles on the fly** based on project needs — the profile defines the starting roster, not a hard limit. New roles are named following each domain's themed naming convention.

---

## What's Inside

```
crescendo-agent-template/              ← Fully self-contained
├── README.md                          # This file
├── LICENSE                            # Apache License, Version 2.0
├── NOTICE                             # Required attribution notices (preserved in derivatives)
├── CRESCENDO.md                       # Full guide, architecture, AI ingestion instructions
├── GEMINI.md                          # 43 behavioral directives for the Coordinator
├── justfile                           # 8 automation commands (preflight, sanitize, inspect, poll, etc.)
├── .agents/                           # Workspace-level AI config (auto-discovered)
│   ├── AGENTS.md                      # Coordinator bootstrap identity + command table
│   └── skills/                        # 9 packaged skills (zero external dependencies)
│       ├── using-git-worktrees/       # Worktree isolation protocol
│       ├── conductor-worktree-hitl/   # Parallel execution + HITL via GitHub Issues
│       ├── crescendo-init/            # Project bootstrapper
│       ├── conductor-setup/           # Conductor scaffolding
│       ├── conductor-implement/       # Track execution engine
│       ├── conductor-newTrack/        # Track creation
│       ├── conductor-review/          # Code review protocol
│       ├── conductor-status/          # Progress dashboard
│       └── conductor-revert/          # Git-aware revert assistant
├── input/                             # Drop project files here
├── .worktrees/                        # Agent workspaces (created at runtime)
└── conductor/                         # Orchestration brain
    ├── bin/                           # 9 scripts
    │   ├── preflight_check.py         # Infrastructure validator
    │   ├── orchestration_state.py     # State machine (crash recovery, resume)
    │   ├── run_deterministic_gates.py # Quality gates (tests, lint, scope)
    │   ├── cross_validate_outputs.py  # Contradiction detection
    │   ├── sanitize_inputs.py         # Input sanitization
    │   └── ...                        # (4 more: git status, inspector, GHI tools)
    ├── profiles/                      # 5 domain configurations
    ├── schemas/                       # Claims JSON schema (EAV format)
    ├── templates/                     # Setup templates (style guides)
    └── workflow.md                    # Execution protocols (239 lines)
```

---

## Key Concepts

| Concept | Summary | Details |
|---------|---------|---------|
| **Profiles** | Domain-specific configs (roles, gates, autonomy) | [CRESCENDO.md §5](CRESCENDO.md#5-domain-profiles) |
| **43 Directives** | The Coordinator's behavioral rules | [CRESCENDO.md §6](CRESCENDO.md#6-the-43-directives-geminimd) |
| **Scribe Agent** | Required observer — forensic log of every run | [CRESCENDO.md §6](CRESCENDO.md#6-the-43-directives-geminimd) (Directive 43) |
| **Approach Validation** | Agents submit plans before coding — conflicts caught early | [CRESCENDO.md §6](CRESCENDO.md#6-the-43-directives-geminimd) (Directive 37) |
| **HITL Questions** | Agents post questions to GitHub Issues for human answers | [CRESCENDO.md §6](CRESCENDO.md#6-the-43-directives-geminimd) (Directive 39) |
| **Quality Gates** | Deterministic + heuristic checks before merge | [CRESCENDO.md §7](CRESCENDO.md#7-quality-gates) |
| **Autonomy Levels** | Full / Checkpoint / Supervised | [CRESCENDO.md §8](CRESCENDO.md#8-autonomy-system) |
| **Quota Recovery** | 3-layer system (estimate → wait → stop) | [CRESCENDO.md §10](CRESCENDO.md#10-quota-recovery-system) |
| **Contradiction Detection** | Claims-based (EAV) + text extraction | [CRESCENDO.md §14](CRESCENDO.md#14-claims--contradiction-detection) |
| **Self-Contained** | All skills shipped, zero plugin dependencies | [CRESCENDO.md §18](CRESCENDO.md#18-self-contained-architecture) |
| **AI Ingestion** | How future AIs should read this system | [CRESCENDO.md §19](CRESCENDO.md#19-for-future-ais-how-to-ingest-this-document) |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [CRESCENDO.md](CRESCENDO.md) | **Full guide** — architecture, usage, profiles, all 20 sections |
| [GEMINI.md](GEMINI.md) | 43 directives the Coordinator must follow |
| [conductor/workflow.md](conductor/workflow.md) | Execution protocols, gate rules, aggregation strategies |
| [conductor/profiles/](conductor/profiles/) | Domain-specific JSON configurations |
| [conductor/schemas/claims.schema.json](conductor/schemas/claims.schema.json) | EAV claims format for contradiction detection |


---

## Acknowledgments

Crescendo was built on the shoulders of an open-source community. The following people, articles, and repositories were direct inspirations:

| Contributor | Contribution | Link |
|-------------|-------------|------|
| **Riccardo Carlesso** ([@palladius](https://github.com/palladius)) | Original "Crescendo of Agents" blog series, `conductor-worktree-hitl` skill, Conductor++ architecture, and the Agostina coordinator concept | [Blog Post (Part 2)](https://ricc.rocks/en/posts/technology/2026-06-16-crescendo-of-agents-part-2/) |
| **Keith** | Conductor extension — the Rails-like orchestration framework that Crescendo's track system is built on | [gemini-cli-extensions/conductor](https://github.com/gemini-cli-extensions/conductor) |
| **Barrett Storck** | `gemini-superpowers` plugin, including the `using-git-worktrees` skill for parallel agent isolation | [barretstorck/gemini-superpowers](https://github.com/barretstorck/gemini-superpowers) |
| **Richard Seroter** | "One prompt, four subagents" article — the parallel subagent dispatch pattern that inspired the architecture | [seroter.com](https://seroter.com/2026/06/01/one-prompt-four-subagents-and-ninety-seconds-to-get-a-working-app/) |
| **Paul** (AI Positive) | "State on Disk" persistence pattern — how Crescendo survives quota interruptions | [AI Positive Substack](https://aipositive.substack.com/p/how-i-turned-gemini-cli-into-a-multi) |

> The name "Crescendo" and the musical metaphor (Maestro, Score) come from Riccardo's original vision of a "crescendo of agents" — a single coordinator that grows the ensemble from a soloist to a full orchestra.

---

## License

Copyright 2026 Irongate Property Collective

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

> http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the [LICENSE](LICENSE) file for the full license text and the [NOTICE](NOTICE) file for required attribution notices.

# Agent Directives: Crescendo Flow

When acting as a subagent or coordinator in this repository, you MUST follow these rules:

## Isolation & Access Control
1. **Worktrees**: All development tasks MUST be performed in isolated branches within the `.worktrees/` directory. Use the `using-git-worktrees` skill to set up your environment.
2. **Conductor Integration**: Use the `conductor-worktree-hitl` skill to implement tasks tracked in the Conductor workflow.
3. **No Direct Main Pushes**: Subagents must only commit to their local feature branches and use Git Notes for summaries. The coordinator handles merges.
4. **Read-Only Conductor Access**: The `conductor/` directory in your worktree is a READ-ONLY copy. Do NOT modify `workflow.md`, `profile.json`, `product.md`, or any other conductor config file from within a worktree. If you need a config change, request it from the Coordinator.
5. **No Cross-Agent File Access**: Do NOT read files from other agents' worktrees or output directories. You may only access files within your own worktree and the shared truth documents specified in your agent archetype's `context_files`.

## Input Sanitization (MANDATORY)
6. **Sanitize Before Consuming**: Before reading ANY file from the `input/` folder, the Coordinator MUST first run `just sanitize-inputs` (or `python conductor/bin/sanitize_inputs.py`). Only files in `input/.sanitized/` should be consumed by agents. NEVER read raw input files directly.
7. **Manual Review for Binaries**: PDF, DOCX, and XLSX files in `input/` cannot be automatically sanitized. The Coordinator must flag these for human review before feeding them to agents.

## Domain Profile
8. **Profile-Driven Execution**: Read `conductor/profile.json` before dispatching any agents. It defines the isolation strategy, agent roles, quality gates, data classification, and budget limits.
9. **Respect Data Classification**: If `profile.json` specifies `data_classification: confidential`, agents must NOT include any content from shared truth documents in publicly-facing outputs.
10. **Respect Budget Limits**: Do NOT spawn more agents than `budget.max_agents` allows.

## Quality Gates & Contradiction Resolution
11. **Cross-Validate Before Merging**: Before any merge or final aggregation, the Coordinator MUST run `python conductor/bin/cross_validate_outputs.py`. If HIGH-severity contradictions are found, the merge is BLOCKED until a human resolves them.
12. **Project Prompts**: Check the `input/.sanitized/` folder for current PRDs and constraints.

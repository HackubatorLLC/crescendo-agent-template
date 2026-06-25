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
12. **Run Deterministic Gates First**: Before invoking any heuristic (LLM-based) quality gate, the Coordinator MUST run `python conductor/bin/run_deterministic_gates.py`. If any required deterministic gate fails, do NOT proceed to heuristic review — fix the deterministic failures first.
13. **Project Prompts**: Check the `input/.sanitized/` folder for current PRDs and constraints.

## Budget & Cost Control
14. **Cost Estimation Before Dispatch**: If `profile.json` has `budget.cost_estimation_before_dispatch: true`, the Coordinator MUST print the estimated agent count and request human confirmation before spawning agents.
15. **Circuit Breaker**: If cumulative token usage exceeds `budget.circuit_breaker_token_limit`, pause all agents and ask the human whether to continue or abort.

## Phased Execution
16. **Respect Phase Order**: If `profile.json` defines a `phases` array, the Coordinator MUST execute phases sequentially. Agents within a phase may run in parallel, but all agents in Phase N must complete before Phase N+1 begins.
17. **Dependency Enforcement**: If a phase fails (per the `failure_strategy`), do NOT start subsequent phases. Report the failure and wait for human direction.

## Failure Handling
18. **Follow the Failure Strategy**: Read `profile.json`'s `failure_strategy.strategy` to determine behavior when agents fail:
    - `all_or_nothing`: If any agent fails, roll back all changes and report.
    - `best_effort`: Merge successful outputs, flag failures in the report.
    - `partial_merge_with_approval`: Merge successful outputs only after human approves the partial result.
19. **Retry Policy**: If `failure_strategy.retry_failed` is `true`, retry failed agents up to `failure_strategy.max_retry_attempts` times before declaring failure.

## Orchestration State (Crash Recovery)
20. **Initialize State**: At the start of every orchestration run, run `python conductor/bin/orchestration_state.py init` to create `orchestration_state.json`.
21. **Track Agent Status**: Register each agent and update its status as it progresses. If the Coordinator crashes, a new session can run `python conductor/bin/orchestration_state.py resume` to identify which agents need re-dispatch.


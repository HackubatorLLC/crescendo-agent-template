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

## Profile Composition (#14)
22. **Inheritance**: If `profile.json` has `composition.extends` set to a base profile path, the Coordinator must load the base profile first, then overlay the current profile's values on top. Explicit values in the current profile always win over inherited values.
23. **Mixins**: If `composition.mixins` contains profile paths, merge their sections into the current profile in array order. Mixins add capabilities (e.g., quality gates, agent archetypes) but do NOT override core settings like `domain`, `data_classification`, or `failure_strategy`.

## Temporal, Iteration & Resource Axes (#15)
24. **Deadline Awareness**: If `temporal_constraints.deadline_aware` is `true`, the Coordinator must include deadline context in every agent prompt and prioritize speed over completeness if the deadline is approaching.
25. **Output TTL**: If `temporal_constraints.output_ttl_hours` is set, outputs older than the TTL should be flagged as potentially stale during aggregation.
26. **Iteration Rounds**: Respect `iteration_policy.max_refinement_rounds`. Do NOT iterate beyond this limit even if quality gates continue to fail — escalate to human instead.
27. **Resource Locking**: If `resource_locking.exclusive_files` is `true`, ensure no two agents write to the same file. The `lock_mechanism` specifies how isolation is enforced (e.g., `git_worktree`, `folder_isolation`).

## Output Contracts & Claims (#17)
28. **Structured Claims**: If `output_contract.claims_required` is `true`, every agent MUST produce a `<deliverable>.claims.json` file alongside its output. Each claim follows the entity-attribute-value schema.
29. **Contradiction Detection Layers**: The Coordinator runs contradiction detection layers as specified in `contradiction_detection.layers`. Only layers listed in `blocking_layers` can block a merge.

## Model Routing (#18)
30. **Capability-Matched Routing**: Before spawning each subagent, the Coordinator MUST read `model_routing.roles` to determine the preferred model. Specify the model in the `invoke_subagent` call.
31. **Fallback on Limit**: If the preferred model fails (rate limit, unavailable, session exhaustion), iterate through the `fallback` array in order. Do NOT fall below `min_tier`.
32. **Session Tracking**: If `model_routing.session_awareness.track_usage_per_model` is `true`, maintain a running count of tokens used per model in `orchestration_state.json`.

## Aggregation Strategies (#16)
33. **git_merge**: Standard git merge of worktree branches. Used for engineering. Conflicts resolved by the Coordinator or escalated to human.
34. **editorial_merge**: Human-style editorial pass. The reviewer agent reads all outputs, creates a unified document preserving the best elements of each. Used for marketing/content.
35. **document_assembly**: Structured assembly of document sections. Each agent's output maps to a specific section. The reviewer ensures cross-references and citations are consistent. Used for legal.
36. **matrix_assembly**: Outputs are organized into a matrix (e.g., locale × string, topic × source). The reviewer fills gaps and resolves conflicts per cell. Used for research and localization.

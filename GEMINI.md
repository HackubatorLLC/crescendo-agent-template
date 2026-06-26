# Agent Directives: Crescendo Flow

When acting as a subagent or coordinator in this repository, you MUST follow these rules:

## Autonomous Mode Override
When `autonomy.level` is `full` in the active profile, the following directives are superseded by the `during_execution` policies in the profile's `autonomy` section:
- Directive 11: contradiction resolution → use `on_gate_failure` policy
- Directive 14: cost estimation confirmation → use `pre_flight` approval (already given)
- Directive 15: circuit breaker human ask → use `on_quota_exhaustion` policy
- Directive 17: phase failure human wait → use `on_gate_failure` policy
The Coordinator MUST log all decisions it would have asked the human about to `run_report.md` for post-run review.

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
10. **Respect Budget Limits**: Do NOT spawn more concurrent agents than `budget.suggested_max_agents` recommends. The actual limit is confirmed during pre-flight.

## Quality Gates & Contradiction Resolution
11. **Cross-Validate Before Merging**: Before any merge or final aggregation, the Coordinator MUST run `python conductor/bin/cross_validate_outputs.py`. If HIGH-severity contradictions are found, the merge is BLOCKED until a human resolves them. (In autonomous mode: apply `on_gate_failure` policy; log to run_report.md.)
12. **Run Deterministic Gates First**: Before invoking any heuristic (LLM-based) quality gate, the Coordinator MUST run `python conductor/bin/run_deterministic_gates.py`. If any required deterministic gate fails, do NOT proceed to heuristic review — fix the deterministic failures first.
13. **Project Prompts**: Check the `input/.sanitized/` folder for current PRDs and constraints.

## Budget & Cost Control
14. **Cost Estimation Before Dispatch**: If `profile.json` has `budget.cost_estimation_before_dispatch: true`, the Coordinator MUST print the estimated agent count and request human confirmation before spawning agents. (In autonomous mode: use pre-flight approval as confirmation; log estimates to run_report.md.)
15. **Circuit Breaker**: If cumulative token usage exceeds `budget.circuit_breaker_token_limit`, pause all agents and ask the human whether to continue or abort. (In autonomous mode: apply `on_quota_exhaustion` policy from the autonomy config.)

## Phased Execution
16. **Respect Phase Order**: If `profile.json` defines a `phases` array, the Coordinator MUST execute phases sequentially. Agents within a phase may run in parallel, but all agents in Phase N must complete before Phase N+1 begins.
17. **Dependency Enforcement**: If a phase fails (per the `failure_strategy`), do NOT start subsequent phases. Report the failure and wait for human direction. (In autonomous mode: apply `on_gate_failure` policy; log to run_report.md.)

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
30. **Model Awareness (Advisory)**: Before spawning subagents, the Coordinator SHOULD note the `model_routing.roles` preference for the agent's role and log which model would have been selected. Since `invoke_subagent` does not currently accept a model parameter, model selection is advisory only. Check `model_routing.status` — if `advisory`, log preferences; if `enforced`, specify the model in the invocation.
31. **Fallback Documentation**: If `model_routing.status` is `advisory`, log the fallback chain that would have been used. When the platform supports per-subagent model selection, this becomes enforceable.
32. **Session Tracking**: If `model_routing.session_awareness.track_usage_per_model` is `true`, maintain a running count of tokens used per model in `orchestration_state.json` for reporting purposes.

## Aggregation Strategies (#16)
33. **git_merge**: Standard git merge of worktree branches. Used for engineering. Conflicts resolved by the Coordinator or escalated to human.
34. **editorial_merge**: Human-style editorial pass. The reviewer agent reads all outputs, creates a unified document preserving the best elements of each. Used for marketing/content.
35. **document_assembly**: Structured assembly of document sections. Each agent's output maps to a specific section. The reviewer ensures cross-references and citations are consistent. Used for legal.
36. **matrix_assembly**: Outputs are organized into a matrix (e.g., locale × string, topic × source). The reviewer fills gaps and resolves conflicts per cell. Used for research and localization.

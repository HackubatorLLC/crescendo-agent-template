# Conductor Workflow

## Default Rules
- Code must reach >80% test coverage before completion.
- Agent tasks are committed per-task as defined by the track.
- Worktrees are utilized for isolated development (via `condutree` skill).
- The `just` task runner is used for orchestration and polling worktree status.

## Worktree Isolation Protocol
All feature development must happen within the `.worktrees/` directory. Checkouts should follow the `condutree` execution flow.

## Cross-Validation Protocol

Before any merge or final aggregation of agent outputs, the Coordinator **MUST** run the cross-validation script:

```bash
python conductor/bin/cross_validate_outputs.py
```

### Blocking rules

- If the generated `contradiction_report.md` contains any **HIGH** severity findings, the Coordinator **MUST NOT** proceed with the merge. Instead, the contradictions must be presented to the human operator for manual resolution before the workflow can continue.
- **MEDIUM** severity findings should be clearly flagged in the merge summary but **do not block** the merge.
- **LOW** severity findings are informational and may be included in the merge summary at the Coordinator's discretion.

## Deterministic Quality Gates

Before any heuristic (LLM-based) review, run all deterministic gates first:

```bash
python conductor/bin/run_deterministic_gates.py
```

Deterministic gates (unit tests, lint, citation audits, source verification) produce binary PASS/FAIL results. If any required deterministic gate fails, the Coordinator must fix the issue before invoking heuristic reviewers. This prevents wasting LLM calls on code that has known structural defects.

## Phased Execution Protocol

If `profile.json` defines a `phases` array, the Coordinator must execute phases sequentially:

1. **Phase N starts**: Dispatch all agents listed in Phase N's `agent_roles` in parallel.
2. **Phase N completes**: Wait for ALL agents in Phase N to report completion (or failure).
3. **Evaluate**: If the `failure_strategy` is `all_or_nothing` and any Phase N agent failed, STOP. Do not proceed to Phase N+1.
4. **Phase N+1 starts**: Only after Phase N completes successfully.

This replaces the flat "dispatch all agents at once" model and enables DAG-style dependencies.

## Failure Strategy Protocol

Read `profile.json`'s `failure_strategy` to determine behavior on agent failure:

| Strategy | On Failure |
|----------|-----------|
| `all_or_nothing` | Roll back all worktree changes. Report failure to human. |
| `best_effort` | Merge successful outputs. Flag failures in merge report. |
| `partial_merge_with_approval` | Present successful outputs + failure report to human. Merge only with explicit approval. |
| `retry_failed` (modifier) | If `retry_failed: true`, retry failed agents up to `max_retry_attempts` times before applying the base strategy. |

## Orchestration State Management

Every orchestration run must be tracked for crash recovery:

```bash
# At run start:
python conductor/bin/orchestration_state.py init --run-id <unique-id> --profile conductor/profile.json

# When dispatching an agent:
python conductor/bin/orchestration_state.py register --run-id <id> --agent-id <name> --role <role> --phase <phase>

# When an agent reports status:
python conductor/bin/orchestration_state.py update --run-id <id> --agent-id <name> --status <completed|failed>

# To check current state:
python conductor/bin/orchestration_state.py status --run-id <id>

# After a crash, to find what needs re-dispatch:
python conductor/bin/orchestration_state.py resume --run-id <id>
```

The `orchestration_state.json` file persists to disk, so if the Coordinator crashes mid-run, a new session can read it and resume without re-dispatching completed agents.

## Aggregation Strategies

The `aggregation.strategy` field in `profile.json` determines how agent outputs are combined:

### `git_merge`
Standard git merge. Each agent works in an isolated worktree branch. The Coordinator merges branches sequentially, resolving conflicts. If auto-merge fails, the conflict is presented to the human.

### `editorial_merge`
The reviewer agent receives all outputs and produces a single unified document. This is NOT a mechanical merge — the reviewer exercises editorial judgment to select the strongest content, resolve tonal inconsistencies, and create a coherent narrative. Used for marketing and content domains.

### `document_assembly`
Each agent's output maps to a predefined section of the final document. The reviewer agent assembles sections in order, verifies cross-references, ensures citation consistency, and checks that conclusions in later sections don't contradict findings in earlier ones. Used for legal and compliance domains.

### `matrix_assembly`
Outputs are organized into a two-dimensional matrix (e.g., locale × string for localization, topic × source for research). The reviewer fills gaps, flags inconsistencies across matrix cells, and produces both the assembled matrix and a gap analysis report. Used for research and localization domains.

## Model Routing Protocol

When spawning subagents, the Coordinator must follow the model routing policy defined in `profile.json`:

1. Read `model_routing.roles.<role_type>` for the agent being spawned.
2. Use the first model in `preferred` that is available.
3. If the preferred model fails (rate limit, session exhaustion, error), try each model in `fallback` in order.
4. Never fall below `min_tier` — if all fallbacks above `min_tier` are exhausted, report to human.
5. If `session_awareness.track_usage_per_model` is `true`, log token usage per model in `orchestration_state.json`.

## Output Contracts

If `output_contract.claims_required` is `true` in the profile, every agent must produce two files:
1. The deliverable (e.g., `output/analysis.md`)
2. A claims file (e.g., `output/analysis.claims.json`)

The claims file follows the entity-attribute-value schema:
```json
{
  "claims": [
    {
      "entity": "string — the subject of the claim",
      "attribute": "string — what aspect is being claimed",
      "value": "string — the asserted value",
      "confidence": "number 0-1 — agent's self-assessed confidence",
      "source": "string — where this claim comes from"
    }
  ]
}
```

The cross-validator uses these claims for Layer 1 deterministic contradiction detection.

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


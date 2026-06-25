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

## Quota Recovery Layers

The orchestrator uses a layered recovery strategy when quota or rate limits are hit mid-run:

### Layer A — Pre-emptive Estimation (Always Active)

- Before dispatching any agent, the Coordinator estimates the quota cost of the task.
- All agents are **registered in `orchestration_state.json` before dispatch**, so the state file always reflects the intended work, even if a crash occurs before the agent starts.
- If estimated cost exceeds remaining quota, the Coordinator defers the task or batches it into a lower-cost phase.

### Layer B — Timer-Based Auto-Resume (Best-Effort)

- When a quota pause is triggered, the Coordinator sets a timer and attempts to auto-resume after the cooldown period.
- **This layer is best-effort only.** It may fail due to:
  - Session timeout (the agent's session expires before the timer fires)
  - Stray message cancellation (an unrelated system message cancels the pending timer)
- **Probe operation**: `view_file` on `orchestration_state.json` — this has **zero quota cost** and confirms the state file is still readable before resuming.
- **Thrashing protection**: If quota pauses occur **more than 2 times in a single run**, Layer B is skipped entirely and the Coordinator proceeds directly to Layer C. This prevents infinite pause-resume loops that waste session time without making progress.

### Layer C — User-Assisted Resume (Guaranteed Fallback)

- If Layer B fails or is skipped (due to thrashing protection), the Coordinator writes the full orchestration state to `orchestration_state.json` and generates a **resumption briefing** in `run_report.md`.
- The resumption briefing includes: current phase, completed agents, pending agents, the reason for the pause, and the exact command to resume.
- The human operator can resume the run in a new session using:
  ```bash
  python conductor/bin/orchestration_state.py resume --run-id <id>
  ```
- This layer is **guaranteed** to work because it has no dependency on timer mechanics or session persistence.

## Auto-Merge Safety Rules

All merges to the `main` branch must follow these safety rules:

1. **Fast-forward or clean merge only.** Auto-merge to `main` MUST be a fast-forward or a clean merge with no conflicts. Squash merges are acceptable if configured in `profile.json`.

2. **Conflict → PR, no merge.** If the merge has conflicts, create the Pull Request but **do NOT merge**. Log the following message to `run_report.md`:
   ```
   Auto-merge blocked: main has diverged.
   ```
   The PR will remain open for human resolution.

3. **Never force-push.** NEVER force-push (`git push --force` or `git push --force-with-lease`) to **any** branch — not `main`, not feature branches, not worktree branches.

4. **Post-merge deterministic gates.** Run `run_deterministic_gates.py` on the **POST-MERGE result** before pushing:
   ```bash
   python conductor/bin/run_deterministic_gates.py
   ```
   This validates that the merged code passes all deterministic quality checks (tests, lint, citations, source verification).

5. **Gate failure → abort and revert.** If post-merge gates fail, **abort the push** and revert the local merge:
   ```bash
   git merge --abort  # if merge is in progress
   git reset --hard HEAD~1  # if merge was committed locally
   ```
   Log the failure details in `run_report.md` and flag for human review.

### Commit Scope Enforcement

The following rules augment the auto-merge safety rules with directory-level write restrictions:

- The `commit_scope` field from the pre-flight configuration (in `profile.json`) defines **which directories each agent is permitted to modify**.
- **NTFS ACL enforcement**: On Windows, combine with `icacls` to deny-write on directories outside the agent's declared scope:
  ```powershell
  # Deny write access to directories outside commit_scope
  icacls "C:\path\to\repo\outside-dir" /deny "AgentUser:(W)" /T
  ```
  This provides OS-level enforcement that cannot be bypassed by the agent process.
- **Deterministic gate validation**: A `scope_validation` deterministic gate checks `git diff --name-only` against `commit_scope` after each agent commit:
  ```bash
  python conductor/bin/run_deterministic_gates.py --gate scope_validation
  ```
  If any modified file falls outside the declared `commit_scope`, the gate fails and the commit is rejected.

## Autonomous Decision-Making

When the Coordinator encounters ambiguity during execution, it classifies the decision into one of the following **ambiguity classes** and acts accordingly:

### Ambiguity Classes

| Class | Examples | Action |
|-------|----------|--------|
| `cosmetic` | Formatting, naming conventions, code style, whitespace | Coordinator uses **best judgment** and proceeds autonomously. |
| `architectural` | Structural decisions, API design, module boundaries, dependency choices | **`write_state_and_stop`** — save state and pause for human review. |
| `data_destructive` | File deletions, database migrations, schema changes, data transformations | **`write_state_and_stop`** — save state and pause for human review. |

### Default Behavior

If an ambiguity does not clearly fit into a defined class, the default policy is:

> **`best_judgment_with_conservative_fallback`**

The Coordinator makes a conservative decision (preferring no-op or minimal change) and logs it for post-run review. If confidence is below 0.5, it falls back to `write_state_and_stop`.

### Decision Logging

All autonomous decisions (including those made under `cosmetic` and `best_judgment_with_conservative_fallback`) must be logged to `run_report.md` with the following fields:

| Field | Description |
|-------|-------------|
| `category` | The ambiguity class (`cosmetic`, `architectural`, `data_destructive`, or `default`) |
| `what_was_ambiguous` | A brief description of the ambiguous situation |
| `decision_made` | What the Coordinator decided to do |
| `confidence` | Self-assessed confidence (0.0–1.0) in the decision |

### Rate Limiting

- **Maximum autonomous decisions per run**: `10` (configurable via `profile.json` field `max_autonomous_decisions`).
- If the limit is exceeded, the Coordinator must **pause for human review** regardless of ambiguity class.
- This prevents runaway autonomous behavior in runs that encounter unusual levels of ambiguity.

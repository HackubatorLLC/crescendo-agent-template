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

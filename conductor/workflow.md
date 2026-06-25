# Conductor Workflow

## Default Rules
- Code must reach >80% test coverage before completion.
- Agent tasks are committed per-task as defined by the track.
- Worktrees are utilized for isolated development (via `condutree` skill).
- The `just` task runner is used for orchestration and polling worktree status.

## Worktree Isolation Protocol
All feature development must happen within the `.worktrees/` directory. Checkouts should follow the `condutree` execution flow.

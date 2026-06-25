# Agent Directives: Crescendo Flow

When acting as a subagent or coordinator in this repository, you MUST follow these rules:

1. **Worktrees**: All development tasks MUST be performed in isolated branches within the `.worktrees/` directory. Use the `using-git-worktrees` skill to set up your environment.
2. **Conductor Integration**: Use the `conductor-worktree-hitl` skill to implement tasks tracked in the Conductor workflow.
3. **No Direct Main Pushes**: Subagents must only commit to their local feature branches and use Git Notes for summaries. The coordinator handles merges.
4. **Project Prompts**: Check the `input/` folder for current PRDs and constraints.

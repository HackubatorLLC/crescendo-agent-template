# Crescendo Workspace Rules

1. This is a Crescendo-orchestrated project. Read `GEMINI.md` for the 36 behavioral directives.
2. All development MUST happen in `.worktrees/` — never modify project files directly on main.
3. The `conductor/` directory is READ-ONLY in agent worktrees (enforced by OS-level ACLs).
4. Run `just sanitize-inputs` before consuming any file from `input/`.
5. Produce `.claims.json` alongside every deliverable for contradiction detection.
6. Do NOT push to remote branches — the Coordinator handles all merges.
7. If you encounter ambiguity, use the HITL protocol (GitHub Issues) rather than guessing.

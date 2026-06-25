# Orchestration targets for Conductor Crescendo Flow
set shell := ["powershell.exe", "-c"]

default:
    @just --list

# View the unified status of all active parallel worktrees and agents
git-status-condutree:
    python conductor/bin/git_status_patched.py

# Initialize a new agent worktree with shared configuration (.env symlinking)
init-worktree track_id role:
    @echo "Initializing worktree for track {{track_id}} role {{role}}..."
    git worktree add .worktrees/{{track_id}}-{{role}} -b feature/{{track_id}}
    
    @echo "Symlinking conductor/"
    New-Item -ItemType SymbolicLink -Path ".worktrees/{{track_id}}-{{role}}/conductor" -Target "../../conductor" -Force | Out-Null
    
    @echo "Symlinking .env (if exists)"
    if (Test-Path ".env") { New-Item -ItemType SymbolicLink -Path ".worktrees/{{track_id}}-{{role}}/.env" -Target "../../.env" -Force | Out-Null }
    
    @echo "Updating git excludes"
    Add-Content -Path ".git/worktrees/{{track_id}}-{{role}}/info/exclude" -Value "conductor"
    Add-Content -Path ".git/worktrees/{{track_id}}-{{role}}/info/exclude" -Value ".env"
    
    @echo "Worktree ready at .worktrees/{{track_id}}-{{role}}"

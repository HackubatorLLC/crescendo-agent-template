# Orchestration targets for Conductor Crescendo Flow
set shell := ["powershell.exe", "-c"]

default:
    @just --list

# View the unified status of all active parallel worktrees and agents
git-status-condutree:
    python conductor/bin/git_status_patched.py

# Initialize a new agent worktree with shared configuration (read-only copies)
init-worktree track_id role:
    @echo "Initializing worktree for track {{track_id}} role {{role}}..."
    git worktree add .worktrees/{{track_id}}-{{role}} -b feature/{{track_id}}
    
    # DATA ISOLATION: Copy conductor/ as read-only instead of symlinking.
    # Agents must NOT be able to modify shared conductor config — a symlink
    # would let any agent mutate the single source of truth for all worktrees.
    @echo "Copying conductor/ (read-only) into worktree..."
    Copy-Item -Path "conductor" -Destination ".worktrees/{{track_id}}-{{role}}/conductor" -Recurse -Force
    # OS-level enforcement via NTFS ACLs — cannot be bypassed by agents,
    # unlike the IsReadOnly file attribute which any process can flip.
    icacls ".worktrees/{{track_id}}-{{role}}/conductor" /deny "Everyone:(OI)(CI)(W)" /T /Q
    
    @echo "Copying .env (read-only — agents must not mutate shared credentials)"
    if (Test-Path ".env") { Copy-Item -Force ".env" ".worktrees/{{track_id}}-{{role}}/.env"; icacls ".worktrees/{{track_id}}-{{role}}/.env" /deny "Everyone:(W)" /Q }
    
    @echo "Updating git excludes"
    Add-Content -Path ".git/worktrees/{{track_id}}-{{role}}/info/exclude" -Value "conductor"
    Add-Content -Path ".git/worktrees/{{track_id}}-{{role}}/info/exclude" -Value ".env"
    
    @echo "Worktree ready at .worktrees/{{track_id}}-{{role}}"

# Sanitize all files in input/ — strips prompt injections, invisible chars, HTML comments
sanitize-inputs:
    python conductor/bin/sanitize_inputs.py

# Run pre-flight infrastructure check before a Crescendo run
preflight:
    python conductor/bin/preflight_check.py

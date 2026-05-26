#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Configuration: Target repositories and files to synchronize
# ==============================================================================

# List of consumer repositories (Format: "owner/repo")
TARGET_REPOS=(
  "zorphdark/yolandasantacruz-portfolio"
)

# Files to sync from templates/ to the root of target repositories
FILES_TO_SYNC=(
  "AGENTS.core.md"
  "DESIGN-SYSTEM.core.md"
  "SECURITY.md"
  "LICENSE"
  "CONTRIBUTING.md"
  ".gitignore"
  ".aiignore"
  ".claudeignore"
  ".cursorignore"
  ".copilotignore"
  ".gptignore"
  # Monorepo files (uncomment for repositories that use pnpm workspaces)
  # "pnpm-workspace.yaml"
  # ".npmrc"
)

# ==============================================================================
# Helper Functions
# ==============================================================================

# Prepends a header block to a file if it doesn't already contain a check string.
# If the file doesn't exist, it creates a new boilerplate file linked to core.
prepend_if_missing() {
  local FILE_PATH="$1"
  local CHECK_STR="$2"
  local BLOCK_CONTENT="$3"

  if [ -f "$FILE_PATH" ]; then
    if ! grep -q "$CHECK_STR" "$FILE_PATH"; then
      echo "Prepending core reference to $FILE_PATH..."
      local TEMP_FILE
      TEMP_FILE=$(mktemp)
      printf "%b\n\n" "$BLOCK_CONTENT" > "$TEMP_FILE"
      cat "$FILE_PATH" >> "$TEMP_FILE"
      mv "$TEMP_FILE" "$FILE_PATH"
    fi
  else
    echo "Creating new local $FILE_PATH linked to core..."
    printf "%b\n\n## Project-Specific Rules\n\nAdd your local overrides here.\n" "$BLOCK_CONTENT" > "$FILE_PATH"
  fi
}

# ==============================================================================
# Execution Logic
# ==============================================================================

# Setup secure git authentication config to avoid passing tokens in URLs/logs
if [ -n "${SYNC_TOKEN:-}" ]; then
  git config --global url."https://x-access-token:${SYNC_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

# Temporary working directory (creates in workspace to comply with sandboxed environments)
TEMP_DIR=$(mktemp -d ./tmp-sync-XXXXXX 2>/dev/null || mktemp -d)
cleanup() {
  echo "Cleaning up..."
  if [ -n "${SYNC_TOKEN:-}" ]; then
    git config --global --unset-all url."https://x-access-token:${SYNC_TOKEN}@github.com/".insteadOf || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Starting synchronization of scaffolding templates..."

for REPO in "${TARGET_REPOS[@]}"; do
  echo "--------------------------------------------------"
  echo "Processing target repository: $REPO"
  echo "--------------------------------------------------"

  REPO_DIR="$TEMP_DIR/$REPO"
  mkdir -p "$(dirname "$REPO_DIR")"

  # Clone target repo securely (uses HTTPS with token if available, otherwise SSH)
  if [ -n "${SYNC_TOKEN:-}" ]; then
    git clone "https://github.com/${REPO}.git" "$REPO_DIR"
  else
    git clone "git@github.com:${REPO}.git" "$REPO_DIR"
  fi

  # Copy files from templates folder to target root
  CHANGES_MADE=false
  for FILE in "${FILES_TO_SYNC[@]}"; do
    SRC="templates/$FILE"
    DEST="$REPO_DIR/$FILE"

    if [ -f "$SRC" ]; then
      mkdir -p "$(dirname "$DEST")"
      cp "$SRC" "$DEST"
      CHANGES_MADE=true
    else
      echo "Warning: Template $SRC not found, skipping."
    fi
  done

  # Inject inheritance references to AGENTS.md and DESIGN-SYSTEM.md if they are missing
  AGENTS_BLOCK=$(cat << 'EOF'
# Agentic Engineering Protocols

> [!IMPORTANT]
> This repository inherits and extends the global engineering protocols defined in the central [Core Agentic Protocols (AGENTS.core.md)](AGENTS.core.md).
> All contributors and AI agents must adhere to the core guidelines plus the project-specific extensions documented below.
EOF
)
  prepend_if_missing "$REPO_DIR/AGENTS.md" "AGENTS.core.md" "$AGENTS_BLOCK"

  DESIGN_BLOCK=$(cat << 'EOF'
# Design System Specification

> [!IMPORTANT]
> This document inherits and extends the global design and accessibility standards defined in the central [Core Design Specification (DESIGN-SYSTEM.core.md)](DESIGN-SYSTEM.core.md).
> It serves as the **single source of truth** for all visual tokens, custom components, and animation settings specific to this UI. **Strict adherence is mandatory.**
EOF
)
  prepend_if_missing "$REPO_DIR/DESIGN-SYSTEM.md" "DESIGN-SYSTEM.core.md" "$DESIGN_BLOCK"

  # Ensure changes are tracked even if only the injected references changed
  CHANGES_MADE=true

  if [ "$CHANGES_MADE" = true ]; then
    cd "$REPO_DIR"

    # Configure git author
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    # Check if there are changes
    if [ -n "$(git status --porcelain)" ]; then
      echo "Changes detected in $REPO. Preparing update branch..."

      BRANCH_NAME="chore/update-scaffolding"
      
      # Checkout branch (creates if missing, or resets/switches if already exists)
      git checkout -B "$BRANCH_NAME"

      git add .
      git commit -m "chore: sync repository scaffolding templates"

      # Push branch to remote (force push to overwrite previous template updates)
      git push origin "$BRANCH_NAME" --force

      # Detect host repository for PR body link
      CURRENT_REPO="${GITHUB_REPOSITORY:-}"
      if [ -z "$CURRENT_REPO" ]; then
        # Extract from origin URL
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$REMOTE_URL" =~ github.com[:/]([^/]+/[^.]+)(\.git)? ]]; then
          CURRENT_REPO="${BASH_REMATCH[1]}"
        fi
      fi

      if command -v gh >/dev/null 2>&1; then
        # Open Pull Request via GitHub CLI
        if [ -n "${SYNC_TOKEN:-}" ]; then
          export GITHUB_TOKEN="$SYNC_TOKEN"
        fi
        
        # Check if PR already exists
        PR_EXISTS=$(gh pr list --head "$BRANCH_NAME" --state open --json number -q '.[0].number')

        PR_BODY="This automated PR syncs the latest repository scaffolding templates (AGENTS.md, DESIGN-SYSTEM.md, SECURITY.md, etc.)"
        if [ -n "$CURRENT_REPO" ]; then
          PR_BODY="$PR_BODY from the central [repository-scaffolding](https://github.com/${CURRENT_REPO}) repository."
        else
          PR_BODY="$PR_BODY from the central repository."
        fi

        if [ -z "$PR_EXISTS" ]; then
          echo "Opening a new Pull Request..."
          gh pr create \
            --title "chore: sync repository scaffolding templates" \
            --body "$PR_BODY" \
            --base main \
            --head "$BRANCH_NAME"
        else
          echo "Pull Request #$PR_EXISTS already exists and was successfully updated."
        fi
      else
        echo "Warning: GitHub CLI (gh) is not installed or not in PATH. Skipping Pull Request creation/check."
      fi
    else
      echo "No changes detected for $REPO."
    fi
    
    cd - > /dev/null
  fi
done

echo "Scaffolding sync completed successfully!"

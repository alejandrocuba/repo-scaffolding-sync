#!/usr/bin/env bash
set -euo pipefail

# Resolve the absolute path of the repository root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REPOS_FILE="$PROJECT_ROOT/target-repos.yml"
FILES_FILE="$PROJECT_ROOT/files-to-sync.yml"

# Load target repositories from target-repos.yml
TARGET_REPOS=()
if [ -f "$REPOS_FILE" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # Skip empty lines, comments, and non-list lines
    [[ -z "$line" || "$line" =~ ^# || ! "$line" =~ ^-[[:space:]]* ]] && continue
    # Extract the repository name (strip the leading '-' and whitespace)
    repo="${line#*-}"
    repo="${repo#"${repo%%[![:space:]]*}"}"
    repo="${repo%"${repo##*[![:space:]]}"}"
    # Strip any leading/trailing quotes
    repo="${repo#[\"\']}"
    repo="${repo%[\"\']}"
    TARGET_REPOS+=("$repo")
  done < "$REPOS_FILE"
else
  echo "Error: Repositories configuration file not found at $REPOS_FILE" >&2
  exit 1
fi

# Load files to synchronize from files-to-sync.yml
FILES_TO_SYNC=()
if [ -f "$FILES_FILE" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # Skip empty lines, comments, and non-list lines
    [[ -z "$line" || "$line" =~ ^# || ! "$line" =~ ^-[[:space:]]* ]] && continue
    # Extract the file path (strip the leading '-' and whitespace)
    file="${line#*-}"
    file="${file#"${file%%[![:space:]]*}"}"
    file="${file%"${file##*[![:space:]]}"}"
    # Strip any leading/trailing quotes
    file="${file#[\"\']}"
    file="${file%[\"\']}"
    FILES_TO_SYNC+=("$file")
  done < "$FILES_FILE"
else
  echo "Error: Files to synchronize configuration file not found at $FILES_FILE" >&2
  exit 1
fi

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

# Array to keep track of configured url rewrites for cleanup
CONFIGURED_REWRITES=()
cleanup() {
  echo "Cleaning up..."
  for REWRITE in "${CONFIGURED_REWRITES[@]:-}"; do
    if [ -n "$REWRITE" ]; then
      git config --global --unset-all "$REWRITE" || true
    fi
  done
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Temporary working directory (creates in workspace to comply with sandboxed environments)
TEMP_DIR=$(mktemp -d ./tmp-sync-XXXXXX 2>/dev/null || mktemp -d)

echo "Starting synchronization of scaffolding templates..."

for REPO in "${TARGET_REPOS[@]}"; do
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::group::Processing target repository: $REPO"
  else
    echo "--------------------------------------------------"
    echo "Processing target repository: $REPO"
    echo "--------------------------------------------------"
  fi

  # Parse the repository owner and look up repository-specific token
  OWNER=$(echo "$REPO" | cut -d'/' -f1)
  OWNER_UPPER=$(echo "$OWNER" | tr '[:lower:]' '[:upper:]' | tr '-' '_' | tr '.' '_')
  TOKEN_VAR="SYNC_TOKEN_${OWNER_UPPER}"
  # Retrieve variable by name (using indirect variable expansion)
  REPO_TOKEN="${!TOKEN_VAR:-${SYNC_TOKEN:-}}"

  REPO_DIR="$TEMP_DIR/$REPO"
  mkdir -p "$(dirname "$REPO_DIR")"

  # Configure URL rewrite rule for this specific repository
  if [ -n "$REPO_TOKEN" ]; then
    REWRITE_URL="https://x-access-token:${REPO_TOKEN}@github.com/${REPO}.git"
    git config --global url."$REWRITE_URL".insteadOf "https://github.com/${REPO}.git"
    CONFIGURED_REWRITES+=("url.${REWRITE_URL}.insteadOf")
  fi

  # Clone target repo securely
  if [ -n "$REPO_TOKEN" ]; then
    git clone "https://github.com/${REPO}.git" "$REPO_DIR"
  else
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
      echo "Error: Neither $TOKEN_VAR nor SYNC_TOKEN environment variables are set." >&2
      echo "To synchronize templates in GitHub Actions, you must configure a GitHub Personal Access Token (PAT) with write access to target repositories." >&2
      echo "Please add it as a Repository Secret named SYNC_TOKEN or $TOKEN_VAR." >&2
      exit 1
    else
      echo "No token detected for $REPO. Running locally; falling back to SSH cloning..."
      git clone "git@github.com:${REPO}.git" "$REPO_DIR"
    fi
  fi

  # Copy files from templates folder to target root
  CHANGES_MADE=false
  for FILE in "${FILES_TO_SYNC[@]}"; do
    # Skip design system core file if target repository doesn't have a design system
    if [ "$FILE" = "DESIGN-SYSTEM.core.md" ] && [ ! -f "$REPO_DIR/DESIGN-SYSTEM.md" ]; then
      echo "Skipping DESIGN-SYSTEM.core.md: Target repository does not have a design system (DESIGN-SYSTEM.md missing)."
      continue
    fi

    SRC="$PROJECT_ROOT/templates/$FILE"
    DEST="$REPO_DIR/$FILE"

    if [ -f "$SRC" ]; then
      mkdir -p "$(dirname "$DEST")"
      if [ "$FILE" = "pnpm-workspace.yaml" ] && [ -f "$DEST" ]; then
        echo "Merging template and local pnpm-workspace.yaml for $REPO..."
        python3 "$PROJECT_ROOT/.github/scripts/merge-pnpm-workspace.py" "$SRC" "$DEST" "$DEST"
      else
        cp "$SRC" "$DEST"
      fi
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

  if [ -f "$REPO_DIR/DESIGN-SYSTEM.md" ]; then
    DESIGN_BLOCK=$(cat << 'EOF'
# Design System Specification

> [!IMPORTANT]
> This document inherits and extends the global design and accessibility standards defined in the central [Core Design Specification (DESIGN-SYSTEM.core.md)](DESIGN-SYSTEM.core.md).
> It serves as the **single source of truth** for all visual tokens, custom components, and animation settings specific to this UI. **Strict adherence is mandatory.**
EOF
)
    prepend_if_missing "$REPO_DIR/DESIGN-SYSTEM.md" "DESIGN-SYSTEM.core.md" "$DESIGN_BLOCK"
  fi

  # Ensure changes are tracked even if only the injected references changed
  CHANGES_MADE=true

  if [ "$CHANGES_MADE" = true ]; then
    cd "$REPO_DIR"

    # Capture the default branch name of the target repository before switching
    DEFAULT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git branch --show-current 2>/dev/null || echo "main")

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

      # Delete local remote-tracking branch reference to prevent sync/lock conflicts
      git update-ref -d "refs/remotes/origin/$BRANCH_NAME" || true

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
        if [ -n "$REPO_TOKEN" ]; then
          export GITHUB_TOKEN="$REPO_TOKEN"
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
            --base "$DEFAULT_BRANCH" \
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

  # Remove the URL rewrite rule for this specific repository
  if [ -n "$REPO_TOKEN" ]; then
    git config --global --unset-all url."$REWRITE_URL".insteadOf || true
  fi

  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::endgroup::"
  fi
done

echo "Scaffolding sync completed successfully!"

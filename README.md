# Dynamic Scaffolding

[![Sync Scaffolding Templates](https://github.com/alejandrocuba/dynamic-scaffolding/actions/workflows/sync.yml/badge.svg)](https://github.com/alejandrocuba/dynamic-scaffolding/actions/workflows/sync.yml)

This repository serves as the central **single source of truth** for scaffolding files, guidelines, and standards across all our projects.

Any changes made to the files in the `templates/` directory are automatically synchronized and propagated to all consumer repositories listed in the synchronization workflow.

## Structure

```
dynamic-scaffolding/
├── .github/
│   ├── scripts/
│   │   └── sync-repos.sh        # Sync script to clone and push updates
│   └── workflows/
│       └── sync.yml             # GitHub Action triggered on push to main
├── templates/                   # Inherited scaffolding files
│   ├── .aiignore                # Template for AI tool exclusions (global)
│   ├── .claudeignore            # Template for Claude Code exclusions
│   ├── .copilotignore           # Template for GitHub Copilot exclusions
│   ├── .cursorignore            # Template for Cursor IDE exclusions
│   ├── .gitignore               # Template for standard git exclusions
│   ├── .gptignore               # Template for GPT-based agent exclusions
│   ├── AGENTS.core.md           # Core Agentic Protocols spec (read-only)
│   ├── AGENTS.md                # Local Agentic Protocols starter
│   ├── CONTRIBUTING.md          # Project Contribution Guidelines
│   ├── DESIGN-SYSTEM.core.md    # Core Design Specification spec (read-only)
│   ├── DESIGN-SYSTEM.md         # Local Design Specification starter
│   ├── LICENSE                  # MIT License template
│   └── SECURITY.md              # Security and vulnerability disclosure policy
├── target-repos.yml             # Configuration: Target repositories list
└── files-to-sync.yml            # Configuration: Files to synchronize list
```

## How It Works

This repository uses a **Source-Push (PR-based)** synchronization system:

1. **Modify a template**: Edit any file in the `templates/` folder.
2. **Push to `main`**: Commit and push your changes to the `main` branch of this repository.
3. **GitHub Action execution**: The `.github/workflows/sync.yml` workflow is triggered.
4. **Pull Requests created**: The workflow clones the consumer repositories, applies the template changes, and automatically opens a Pull Request (`chore/update-scaffolding`) in each repository.
5. **Review and Merge**: Maintainers of the consumer repositories review the diff and merge the Pull Request to bring the project up-to-date.

## Configuration

### 1. Target Repositories

To register a new project to receive template updates, open [target-repos.yml](target-repos.yml) and add the repository (Format: `owner/repo`) under `repositories`:

```yaml
repositories:
  - owner/repository
```

### 2. Files to Synchronize

To add or remove files from the synchronization loop, edit [files-to-sync.yml](files-to-sync.yml) and update the list of files under `files`. Commented out files (starting with `#`) will be skipped:

```yaml
files:
  - AGENTS.core.md
  - DESIGN-SYSTEM.core.md
  - [Add more files here...]
```

### 3. GitHub Secrets Setup

The synchronization script requires write access to the consumer repositories to push branches and open Pull Requests. To configure this:

1. **Generate a Fine-Grained Personal Access Token (PAT)**:
   Fine-grained PATs are recommended as they follow the principle of least privilege, restricting access to only the specific target repositories.

   1. Go to your GitHub account **Settings** (click your profile picture in the top-right -> **Settings**).
   2. Scroll to the bottom of the left sidebar and click **Developer settings**.
   3. Click **Personal Access Tokens** -> **Fine-grained tokens** -> **Generate new token**.
   4. Fill out the token details:
      * **Token name**: `Template Sync Token`.
      * **Expiration**: Select your preferred duration (e.g., 90 days).
      * **Repository access**: Choose **Only select repositories** and select your target consumer repositories (e.g., `owner/repository`).
      * **Repository permissions**: Expand **Permissions** -> **Repository permissions** -> Find **Contents** and change access to **Read and Write**.
   5. Click **Generate token**.
   6. **Copy the generated token** immediately. *Note: You will not be able to see this token again once you leave the page.*

2. **Configure the Secret in your Template Repository**:
   1. Navigate to the template repository (`alejandrocuba/dynamic-scaffolding`) on GitHub.
   2. Click the **Settings** tab at the top.
   3. In the left sidebar, click **Secrets and variables** -> **Actions**.
   4. Click the green **New repository secret** button.
   5. Fill out the fields:
      * **Name**: `SYNC_TOKEN`
      * **Secret**: *(Paste the Personal Access Token you copied in the previous step)*
   6. Click **Add secret**.

# Dynamic Scaffolding

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
└── templates/                   # Inherited scaffolding files
    ├── .aiignore                # Template for AI tool exclusions (global)
    ├── .claudeignore            # Template for Claude Code exclusions
    ├── .copilotignore           # Template for GitHub Copilot exclusions
    ├── .cursorignore            # Template for Cursor IDE exclusions
    ├── .gitignore               # Template for standard git exclusions
    ├── .gptignore               # Template for GPT-based agent exclusions
    ├── AGENTS.core.md           # Core Agentic Protocols spec (read-only)
    ├── AGENTS.md                # Local Agentic Protocols starter
    ├── CONTRIBUTING.md          # Project Contribution Guidelines
    ├── DESIGN-SYSTEM.core.md    # Core Design Specification spec (read-only)
    ├── DESIGN-SYSTEM.md         # Local Design Specification starter
    ├── LICENSE                  # MIT License template
    └── SECURITY.md              # Security and vulnerability disclosure policy
```

## How It Works

This repository uses a **Source-Push (PR-based)** synchronization system:

1. **Modify a template**: Edit any file in the `templates/` folder.
2. **Push to `main`**: Commit and push your changes to the `main` branch of this repository.
3. **GitHub Action execution**: The `.github/workflows/sync.yml` workflow is triggered.
4. **Pull Requests created**: The workflow clones the consumer repositories, applies the template changes, and automatically opens a Pull Request (`chore/update-scaffolding`) in each repository.
5. **Review and Merge**: Maintainers of the consumer repositories review the diff and merge the Pull Request to bring the project up-to-date.

## Configuration

### 1. Adding a New Consumer Repository

To register a new project to receive template updates, open [.github/scripts/sync-repos.sh](file:///.github/scripts/sync-repos.sh) and append your repository to the `TARGET_REPOS` array:

```bash
TARGET_REPOS=(
  "owner/my-first-project"
  "owner/my-second-project"
  "owner/new-registered-project" # Add here
)
```

### 2. GitHub Secrets Setup

The synchronization script requires write access to the consumer repositories to push branches and open Pull Requests.

1. Generate a **Personal Access Token (PAT)** on GitHub with `repo` permissions.
2. In this repository, navigate to **Settings** -> **Secrets and variables** -> **Actions**.
3. Create a new repository secret:
   * **Name**: `SYNC_TOKEN`
   * **Value**: *[Your Personal Access Token]*

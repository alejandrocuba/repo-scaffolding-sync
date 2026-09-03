# Dynamic Scaffolding

[![Sync Scaffolding Templates](https://github.com/alejandrocuba/dynamic-scaffolding/actions/workflows/sync.yml/badge.svg)](https://github.com/alejandrocuba/dynamic-scaffolding/actions/workflows/sync.yml)

This repository serves as the central **single source of truth** for scaffolding files, guidelines, and standards across all our projects.

Any changes made to the files in the `templates/` directory are automatically synchronized and propagated to all consumer repositories listed in the synchronization workflow.

## Structure

```
dynamic-scaffolding/
├── .github/
│   ├── scripts/
│   │   ├── merge-package-json.py    # Auto-merge husky/commitlint into package.json
│   │   ├── merge-pnpm-workspace.py  # Merge workspace settings
│   │   └── sync-repos.sh            # Sync script to clone and push updates
│   └── workflows/
│       ├── pr-title-check.yml       # PR Title validation workflow (SemVer)
│       ├── release-please.yml       # Release & Version Bump workflow
│       └── sync.yml                 # GitHub Action triggered on push to main
├── templates/                       # Inherited scaffolding files
│   ├── .aiignore                    # Template for AI tool exclusions (global)
│   ├── .claudeignore                # Template for Claude Code exclusions
│   ├── .commitlintrc.json           # Template for Conventional Commits rules
│   ├── .copilotignore               # Template for GitHub Copilot exclusions
│   ├── .cursorignore                # Template for Cursor IDE exclusions
│   ├── .github/
│   │   └── workflows/
│   │       ├── pr-title-check.yml   # PR Title validation template
│   │       └── release-please.yml   # Release & Version Bump template
│   ├── .gitignore                   # Template for standard git exclusions
│   ├── .gptignore                   # Template for GPT-based agent exclusions
│   ├── .husky/
│   │   └── commit-msg               # Template for commit-msg hook
│   ├── AGENTS.core.md               # Core Agentic Protocols spec (read-only)
│   ├── AGENTS.md                    # Local Agentic Protocols starter
│   ├── CONTRIBUTING.md              # Project Contribution Guidelines
│   ├── DESIGN-SYSTEM.core.md        # Core Design Specification spec (read-only)
│   ├── DESIGN-SYSTEM.md             # Local Design Specification starter
│   └── SECURITY.md                  # Security and vulnerability disclosure policy
├── target-repos.yml                 # Configuration: Target repositories list
└── files-to-sync.yml                # Configuration: Files to synchronize list
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
      - **Token name**: `Template Sync Token`.
      - **Expiration**: Select your preferred duration (e.g., 90 days).
      - **Repository access**: Select **Only select repositories** and pick your target consumer repositories (e.g., `owner/repository`).
      - **Repository permissions**: Expand **Permissions** -> **Repository permissions** and set:
        - **Contents**: Select **Read and Write** (required to push the scaffolding updates branch).
        - **Pull requests**: Select **Read and Write** (required to open and manage Pull Requests via GitHub CLI).
   5. Click **Generate token**.
   6. **Copy the generated token** immediately. _Note: You will not be able to see this token again once you leave the page._

2. **Configure the Secret in your Template Repository**:
   1. Navigate to the template repository (`alejandrocuba/dynamic-scaffolding`) on GitHub.
   2. Click the **Settings** tab at the top.
   3. In the left sidebar, click **Secrets and variables** -> **Actions**.
   4. Click the green **New repository secret** button.
   5. Fill out the fields:
      - **Name**: `SYNC_TOKEN`
      - **Secret**: _(Paste the Personal Access Token you copied in the previous step)_
   6. Click **Add secret**.
   - **Supporting Multiple Tokens**: If your target repositories span different GitHub organizations or user accounts (requiring separate Fine-Grained tokens):
     - Name the secrets using the pattern `SYNC_TOKEN_<OWNER>` (where `<OWNER>` is the uppercase name of the target repository owner/organization, with hyphens or periods replaced with underscores). E.g., for `anothername/project`, name the secret `SYNC_TOKEN_ANOTHERNAME`.
     - Expose the secret as an environment variable in the run step in [.github/workflows/sync.yml](.github/workflows/sync.yml):
       ```yaml
       env:
         SYNC_TOKEN: ${{ secrets.SYNC_TOKEN }}
         SYNC_TOKEN_ANOTHERNAME: ${{ secrets.SYNC_TOKEN_ANOTHERNAME }}
       ```

## Automated Releases & Conventional Commits

All projects synchronized by this scaffolding enforce automated SemVer versioning and GitHub releases via [Release Please](https://github.com/googleapis/release-please).

### Workflow & Quality Gates

1. **Conventional Commits**: Commits and Pull Request titles must follow the [Conventional Commits](https://www.conventionalcommits.org/) format (`feat:`, `fix:`, `chore:`, etc.).
2. **Commitlint Hook**: Local commits are verified before creation via Husky (`.husky/commit-msg`).
3. **PR Title Validation**: The `pr-title-check.yml` workflow verifies in CI that every PR title adheres to Conventional Commits.
4. **Squash & Merge**: When a PR is squash-merged, its title becomes the commit message on `main`.
5. **Release Please Execution**: On push to `main`, `release-please.yml` evaluates commits since the last release tag:
   - `feat:` creates a **MINOR** release (`0.1.0` -> `0.2.0`).
   - `fix:` / `perf:` creates a **PATCH** release (`0.1.0` -> `0.1.1`).
   - `feat!:` / `fix!:` / `BREAKING CHANGE:` creates a **MAJOR** release (`1.0.0` -> `2.0.0`).
   - Release PRs bump `package.json`, update `CHANGELOG.md`, and are automatically squash-merged via `gh pr merge`.

### GitHub Repository Prerequisites

For automated releases to operate successfully in each repository, configure the following repository settings:

1. **Allow Auto-Merge**:
   - Go to **Settings** -> **General** -> **Pull Requests**.
   - Enable **Allow auto-merge**.
2. **Workflow Permissions**:
   - Go to **Settings** -> **Actions** -> **General** -> **Workflow permissions**.
   - Select **Read and write permissions**.
   - Check **Allow GitHub Actions to create and approve pull requests**.
3. **Preventing Redundant Workflows on Release PRs**:
   - In workflows that run on pull requests (e.g., preview deployments or tests), add this condition to skip runs on release branches:
     ```yaml
     if: "${{ !startsWith(github.head_ref, 'release-please') }}"
     ```

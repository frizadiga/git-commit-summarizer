# git-commit-summarizer

Automatically generate [conventional commit](https://www.conventionalcommits.org/) messages by analyzing `git diff` via an LLM.

## Features

- **summarize** — prints a commit message suggestion to stdout (pipe into `git commit -F`)
- **commit** — full workflow: auto-stage, LLM-generate message, confirm/refine, then commit
- Works with any LLM CLI tool (that prints tokens to stdout)
- Enforces conventional commit format, 50/72 rule, present tense

## Prerequisites

- [Zig](https://ziglang.org/download/) 0.17.0-dev+
- Git
- Any binary that prints tokens to stdout

## Installation

```bash
git clone <repo-url>
cd git-commit-summarizer

# Build for development
make build

# Build for production
make release

# Install release build to ~/.local/bin
make install

# Set up environment
make init-env
# Edit .env with your paths, then source it
source .env
```

## Configuration

| Variable | Required | Description |
|---|---|---|
| `LLM_MAIN_ENTRY_BIN` | Yes | Path/name of the LLM CLI binary |
| `ENABLE_HOLY_WORD_CHECK` | No | Set to `1` to enable pre-commit holy-word check |

## Usage

```bash
# Generate a commit message suggestion
git-summarize summarize
git-summarize summarize "optional user hint"

# Full commit workflow
git-summarize commit
git-summarize commit "optional user hint"
```

The `commit` command stages all changes, generates a message via LLM, shows it with a `(y/e/N)` prompt, and commits on acceptance.

## How It Works

The tool captures `git diff`, composes a prompt enforcing conventional commit conventions, pipes it to the configured LLM CLI binary, and returns the generated message. The `commit` command wraps this with auto-staging and interactive confirmation/editing.

# git-commit-summarizer

Explaining the commit message after writing the code is like explaining your own jokes, it's annoying to do it every single time. That's why this tool exists. and generate to comply with [conventional commit](https://www.conventionalcommits.org/) messages format which is tedious to write it manually by hand.

## Features

- **summarize** — prints a commit message suggestion to stdout (pipe into `git commit -F`)
- **commit** — full workflow: auto-stage (`git add .`), LLM-generate message, interactive confirm/refine, then commit
- Works with any LLM CLI tool (that prints tokens to stdout)
- Enforces conventional commit format, 50/72 rule, present tense
- Holy-word / profanity filter (`@DEV:` + configurable word list) blocks commits containing flagged terms
- Works in repos with zero commits (graceful fallback when `HEAD` does not exist)

## Prerequisites

- [Zig](https://ziglang.org/download/) 0.17.0-dev+ or later
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

# Uninstall
make uninstall

# Set up environment
make init-env
# Edit .env with your paths, then source it
source .env

# Clean build artifacts
make clean
```

## Configuration

| Variable | Required | Description |
|---|---|---|
| `LLM_MAIN_ENTRY_BIN` | Yes | Path/name of the LLM CLI binary |
| `ENABLE_HOLY_WORD_CHECK` | No | Set to `1` to enable pre-commit holy-word / profanity check |
| `HOLY_WORDS` | No | Comma-separated list of blocked words (e.g. `tai,cuk,coeg`); only checked if `ENABLE_HOLY_WORD_CHECK=1` |
| `EDITOR` | No | Editor for the `e` (edit) option in confirm prompt (default: `vim`) |
| `VISUAL` | No | Fallback if `EDITOR` is not set |

## Usage

```bash
# Generate a commit message suggestion
git-summarize summarize
git-summarize summarize "optional user hint"

# Full commit workflow
git-summarize commit
git-summarize commit "optional user hint"
```

The `commit` command stages all changes (`git add .`), optionally runs the holy-word / profanity check on added lines, generates a message via LLM, shows it with a `(y/e/N)` prompt, and commits on acceptance. `y` confirms, `e` opens the message in your editor for refinement, anything else aborts.

## How It Works

The tool captures `git diff`, composes a prompt enforcing conventional commit conventions, pipes it to the configured LLM CLI binary, and returns the generated message. The `commit` command wraps this with auto-staging (`git add .`), optional holy-word / profanity detection, and interactive confirmation with `(y/e/N)` — confirm, edit in `$EDITOR`, or abort.

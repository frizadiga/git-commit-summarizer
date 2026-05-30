# Makefile for git-commit-summarizer (Zig)
# Usage: make <target>

.PHONY: help init-env build install uninstall clean

# Default install prefix
PREFIX ?= $(HOME)/.local/bin

# Binary name
BINARY := git-summarize

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

init-env: ## Create .env file with required environment variables
	@if [ -f .env ]; then \
		echo ".env already exists. Remove it first to regenerate."; \
		exit 1; \
	fi
	@echo "Creating .env file..."
	@echo '#!/bin/sh' > .env
	@echo '# Source this file: . ./env' >> .env
	@echo '' >> .env
	@echo '# Path to your LLM CLI binary' >> .env
	@echo 'export LLM_MAIN_ENTRY_BIN=llm' >> .env
	@echo '' >> .env
	@echo '# Optional: enable holy word check' >> .env
	@echo '# export ENABLE_HOLY_WORD_CHECK=1' >> .env
	@echo ".env created. Run: source .env"

build: ## Build for development (debug)
	zig build

release: ## Build for production (ReleaseSafe)
	zig build -Doptimize=ReleaseSafe

install: release ## Build release and symlink binary to PREFIX (default: ~/.local/bin)
	@mkdir -p $(PREFIX)
	@ln -sf $(shell pwd)/zig-out/bin/$(BINARY) $(PREFIX)/$(BINARY)
	@echo "Linked $(BINARY) -> $(PREFIX)/$(BINARY)"
	@echo "Install complete. Ensure $(PREFIX) is in your PATH."

uninstall: ## Remove binary symlink from PREFIX
	@rm -f $(PREFIX)/$(BINARY)
	@echo "Removed $(PREFIX)/$(BINARY)"
	@echo "Uninstall complete."

clean: ## Remove build artifacts
	@rm -rf zig-cache zig-out
	@echo "Cleaned build artifacts."

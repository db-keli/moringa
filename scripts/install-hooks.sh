#!/usr/bin/env bash
set -euo pipefail

HOOKS_DIR="$(git -C "$(dirname "$0")/.." rev-parse --git-dir)/hooks"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

cp "$SCRIPTS_DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "hooks installed"

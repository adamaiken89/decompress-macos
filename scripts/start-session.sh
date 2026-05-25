#!/bin/bash
# Start a new development session: sync with latest main and create a feature branch.
# Usage: ./scripts/start-session.sh <branch-name>
# Example: ./scripts/start-session.sh feat/some-feature

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch-name>"
    echo "Example: $0 feat/my-new-feature"
    exit 1
fi

BRANCH_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_DIR"

# Check for uncommitted changes
if ! git diff --quiet HEAD; then
    echo "You have uncommitted changes. Stashing them..."
    git stash push -m "auto-stash before session start"
    STASHED=true
else
    STASHED=false
fi

# Fetch latest from origin
echo "Fetching latest from origin..."
git fetch origin

# Switch to main and pull latest
echo "Syncing main branch..."
git checkout main
git pull origin main

# Create a new feature branch from main
echo "Creating branch '$BRANCH_NAME' from main..."
git checkout -b "$BRANCH_NAME"

# Restore stashed changes if any
if [ "$STASHED" = true ]; then
    echo "Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "Session started on branch: $BRANCH_NAME"
echo "Ready to develop."

#!/bin/bash
# Install Claude Still Thinking? from source
set -e

REPO="https://github.com/Exorust/claude-still-thinking.git"
APP_NAME="Claude Still Thinking?.app"
INSTALL_DIR="/Applications"
CLONE_DIR=""

# Clone if not already in the repo
if [ ! -f "Package.swift" ]; then
    CLONE_DIR=$(mktemp -d -t claude-still-thinking)
    echo "Cloning repository..."
    git clone --depth 1 "$REPO" "$CLONE_DIR/repo"
    cd "$CLONE_DIR/repo/TimeSpend"
else
    cd "$(dirname "$0")/.."
fi

echo "Building and bundling..."
./scripts/bundle-app.sh

echo "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_NAME}"
cp -R "build/${APP_NAME}" "${INSTALL_DIR}/${APP_NAME}"

echo ""
echo "✓ Installed to ${INSTALL_DIR}/${APP_NAME}"
echo "  Launch from Spotlight or run: open '/Applications/${APP_NAME}'"

# Clean up temp directory if we cloned
if [ -n "$CLONE_DIR" ]; then
    rm -rf "$CLONE_DIR"
fi

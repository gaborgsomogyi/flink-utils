#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="${HOME}/.claude/commands"
mkdir -p "${COMMANDS_DIR}"

cp "${SCRIPT_DIR}/claude-commands/"* "${COMMANDS_DIR}/"
echo "Installed $(ls "${SCRIPT_DIR}/claude-commands" | wc -l | tr -d ' ') Claude command(s) to ${COMMANDS_DIR}"

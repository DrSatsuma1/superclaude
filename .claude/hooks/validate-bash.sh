#!/bin/bash
# Bash command validation hook - prevents token waste from scanning blocked directories
# Blocks commands that reference node_modules, .git, build artifacts, and environment files

COMMAND=$(cat | jq -r '.tool_input.command')

# Allow git commands to operate on any files
if echo "$COMMAND" | grep -qE "^(cd .* && )?git "; then
    exit 0
fi

# Allow npm/chmod/mkdir operations
if echo "$COMMAND" | grep -qE "^(cd .* && )?(npm|chmod|mkdir) "; then
    exit 0
fi

BLOCKED="node_modules|\.env|__pycache__|\.git/|dist/|build/|\.next/|coverage/|\.cache/"

if echo "$COMMAND" | grep -qE "$BLOCKED"; then
    echo "ERROR: Blocked directory pattern detected in bash command" >&2
    echo "Command attempted to access: node_modules, .env, .git, or build artifacts" >&2
    echo "These directories are blocked to prevent excessive token usage" >&2
    echo "Allowed: git, npm, chmod, mkdir commands" >&2
    exit 2
fi

exit 0

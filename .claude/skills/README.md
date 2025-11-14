# Skills Overview

This documentation describes modular knowledge bases for Claude Code that activate contextually. Here's what you need to know:

## Core Concept

"Skills are modular knowledge bases that Claude loads when needed" providing domain-specific guidelines, best practices, code examples, and anti-patterns to avoid.

## Available Skills

The showcase includes six main skills:

1. **skill-developer** — Meta-skill for creating and managing other skills (7 files, 426 lines)

2. **backend-dev-guidelines** — Node.js/Express/TypeScript patterns covering layered architecture, Prisma database access, and error tracking (12 files)

3. **frontend-dev-guidelines** — React/TypeScript/MUI v7 patterns with modern React features and performance optimization (11 files, configured as enforcement guardrail)

4. **route-tester** — JWT cookie authentication testing patterns and debugging (1 file, 389 lines)

5. **error-tracking** — Sentry v8 initialization and monitoring integration (1 file, ~250 lines)

## Integration Process

Skills activate through `skill-rules.json` configuration matching:
- Keywords in user prompts
- File path patterns
- Intent patterns
- Content patterns

Customization typically involves updating `pathPatterns` to match your project structure. For instance, backends might use "src/api/**/*.ts" or "backend/**/*.ts" depending on organization.

## Configuration Enforcement

Skills use two enforcement levels: "suggest" for general guidance and "block" for critical operations. The frontend skill uses blocking enforcement to "prevent MUI v6→v7 incompatibilities."

## Activation Troubleshooting

Common issues include mismatched `pathPatterns`, missing skill-rules.json entries, or unexecutable hook files. Debugging involves verifying directory structure, validating JSON configuration, and testing hooks manually.
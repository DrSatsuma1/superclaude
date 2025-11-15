# Claude Code Infrastructure Showcase

Complete auto-activating skill system for Claude Code that prevents token waste and provides specialized development workflows.

## 🎯 What This Is

A production-ready Claude Code infrastructure featuring:
- **5 Auto-Activating Skills** (backend, frontend, route-testing, error-tracking, skill-developer)
- **10 Specialized Agents** for complex multi-step tasks
- **Bash Validation Hook** that prevents 85% token waste
- **3 Slash Commands** for quick workflows
- **Progressive Disclosure Pattern** - skills under 500 lines with detailed resources

## 📋 Quick Setup (Copy to Another Repo)

### Prerequisites
- Node.js and npm installed
- Claude Code CLI or web interface

### Step-by-Step Instructions

```bash
# 1. Navigate to your target project
cd ~/path/to/your-project

# 2. Copy the entire .claude directory
cp -r ~/path/to/superclaude/.claude .

# 3. Install hook dependencies
cd .claude/hooks
npm install

# 4. Make hooks executable
chmod +x *.sh

# 5. Return to project root
cd ../..

# 6. (Optional) Verify setup
./.claude/verify-setup.sh

# Done! Open your project in Claude Code
```

### ✅ Verify Your Setup

After copying, run the verification script to ensure everything is configured correctly:

```bash
./.claude/verify-setup.sh
```

This will check:
- ✅ settings.json exists
- ✅ All hooks are executable
- ✅ npm dependencies installed
- ✅ Hooks registered in settings.json
- ✅ Skills directory structure
- ⚠️ settings.local.json conflicts

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 Claude Code Infrastructure Setup Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ settings.json found
✅ All 7 hooks are executable
✅ Dependencies installed (tsx found)
✅ UserPromptSubmit hook registered
✅ PreToolUse (bash validation) registered

📊 Summary: All checks passed! Infrastructure is ready.
```

### ⚠️ Critical Setup Requirements

**All 3 steps are required for the infrastructure to work:**

#### 1️⃣ Copy ALL Files (Including settings.json)
```bash
# ✅ CORRECT - Copies everything
cp -r ~/path/to/superclaude/.claude .

# ❌ WRONG - Missing settings.json
cp -r ~/path/to/superclaude/.claude/hooks .claude/
cp -r ~/path/to/superclaude/.claude/skills .claude/
# settings.json not copied! Hooks won't register!
```

**Why settings.json is critical:**
- Registers all hooks (UserPromptSubmit, PreToolUse, PostToolUse, Stop)
- Without it, Claude Code doesn't know the hooks exist
- Contains permissions and MCP server configurations

#### 2️⃣ Install Dependencies
```bash
cd .claude/hooks
npm install
```

**What this installs:**
- `tsx` - TypeScript execution for skill-activation-prompt.ts
- `@types/node` - TypeScript definitions
- Required for UserPromptSubmit hook to work

**Without npm install:**
- Skill activation hook fails silently
- No skill suggestions appear
- Bash validation still works (pure bash script)

#### 3️⃣ Make Hooks Executable
```bash
chmod +x *.sh
```

**Current permissions after copy:**
```
-rw-r--r--  skill-activation-prompt.sh  ❌ Can't execute
-rw-r--r--  validate-bash.sh            ❌ Can't execute
```

**After chmod +x:**
```
-rwxr-xr-x  skill-activation-prompt.sh  ✅ Executable
-rwxr-xr-x  validate-bash.sh            ✅ Executable
```

**Without chmod +x:**
- Hooks registered but can't run
- Error: "Permission denied"

## 📁 What Gets Copied

```
.claude/
├── settings.json              ← REQUIRED: Registers all hooks
├── settings.local.json        ← Optional: Project-specific overrides
├── hooks/                     ← Hook scripts (need npm install + chmod)
│   ├── skill-activation-prompt.sh
│   ├── skill-activation-prompt.ts
│   ├── validate-bash.sh       ← Prevents token waste
│   ├── post-tool-use-tracker.sh
│   ├── tsc-check.sh
│   ├── package.json
│   └── node_modules/          ← Created by npm install
├── skills/                    ← Auto-activating skills
│   ├── skill-rules.json       ← Skill trigger definitions
│   ├── backend-dev-guidelines/
│   ├── frontend-dev-guidelines/
│   ├── route-tester/
│   ├── error-tracking/
│   └── skill-developer/
├── agents/                    ← Specialized task agents
│   ├── README.md
│   └── [10 agent definitions]
└── commands/                  ← Slash commands
    ├── dev-docs.md
    ├── dev-docs-update.md
    └── route-research-for-testing.md
```

## 🔍 Troubleshooting Setup

### Problem: Skills Don't Auto-Activate

**Symptom:** No skill suggestions appear when you mention keywords like "component" or "route"

**Check 1: settings.json exists**
```bash
cat .claude/settings.json
# Should show hook registrations
```

**Fix:** Copy the entire .claude directory, don't copy subdirectories individually

**Check 2: Hooks are executable**
```bash
ls -la .claude/hooks/*.sh
# Should show: -rwxr-xr-x (not -rw-r--r--)
```

**Fix:** Run `chmod +x .claude/hooks/*.sh`

**Check 3: Dependencies installed**
```bash
ls .claude/hooks/node_modules
# Should show tsx, @types/node, etc.
```

**Fix:** Run `cd .claude/hooks && npm install`

### Problem: Bash Validation Not Working

**Symptom:** Commands like `cat node_modules/...` execute instead of being blocked

**Check: validate-bash.sh is executable and registered**
```bash
# Check executable
ls -la .claude/hooks/validate-bash.sh

# Check registered in settings.json
grep -A 5 "PreToolUse" .claude/settings.json
```

**Fix:**
1. `chmod +x .claude/hooks/validate-bash.sh`
2. Verify settings.json has PreToolUse hook configured

### Problem: settings.local.json Conflicts

**Symptom:** Hooks work in superclaude but not in your project

**Cause:** If your project already has `.claude/settings.local.json`, it may override settings.json

**Solution:** Merge configurations
```bash
# Check if settings.local.json exists
cat .claude/settings.local.json

# If it has hooks defined, merge with settings.json hooks
# settings.local.json takes precedence over settings.json
```

## 🎯 How It Works After Setup

Once properly set up, the infrastructure auto-activates based on:

### 1. Keywords in Your Prompts
```
"Create a React component" → frontend-dev-guidelines activates
"Test my API route"        → route-tester activates
"Add error tracking"       → error-tracking (Sentry) activates
```

### 2. Files You're Editing
```
Editing *.tsx files        → frontend-dev-guidelines
Editing routes/*.ts        → backend-dev-guidelines + route-tester
Editing controllers/*.ts   → backend-dev-guidelines + error-tracking
```

### 3. Intent Patterns (Regex)
```
"create.*component"        → frontend-dev-guidelines
"test.*route"              → route-tester
"fix.*bug"                 → Activates debugging agents
```

### 4. Bash Validation (Automatic)
```bash
# ❌ Blocked automatically
cat node_modules/package/file.js
grep -r "text" .git/
find dist/ -name "*.js"

# ✅ Allowed
git status
npm install
mkdir src/components
```

## 📚 What Each Component Does

### Hooks
- **skill-activation-prompt.sh/ts** - Analyzes prompts, suggests relevant skills
- **validate-bash.sh** - Blocks token-wasting bash commands (node_modules, .git, dist)
- **post-tool-use-tracker.sh** - Tracks file edits for context
- **tsc-check.sh** - TypeScript error checking on Stop
- **trigger-build-resolver.sh** - Build issue detection on Stop

### Skills
- **backend-dev-guidelines** - Node.js/Express/TypeScript patterns
- **frontend-dev-guidelines** - React/MUI v7 patterns (block enforcement)
- **route-tester** - JWT route testing patterns
- **error-tracking** - Sentry v8 integration patterns
- **skill-developer** - Meta-skill for creating new skills

### Agents
Specialized autonomous agents for complex tasks:
- code-architecture-reviewer
- code-refactor-master
- refactor-planner
- documentation-architect
- frontend-error-fixer
- auto-error-resolver
- auth-route-debugger
- auth-route-tester
- plan-reviewer
- web-research-specialist

### Slash Commands
- `/dev-docs` - Generate comprehensive project documentation
- `/dev-docs-update` - Update existing documentation
- `/route-research-for-testing` - Map routes and launch tests

## 💡 Usage Examples

### Example 1: Debugging Frontend
```
You: "My React dashboard has errors. Debug and fix them."

What happens:
1. frontend-dev-guidelines skill activates
2. frontend-error-fixer agent launches automatically
3. Bash validation prevents scanning node_modules
4. Errors found and fixed following React best practices
```

### Example 2: Testing Backend Routes
```
You: "Test all my API routes and make sure authentication works"

What happens:
1. route-tester skill activates
2. auth-route-tester agent launches
3. Routes tested with proper JWT cookies
4. Issues identified and fixed
```

### Example 3: Token Waste Prevention
```
You: "Find all instances of 'getUserData' in the codebase"

Traditional approach:
grep -r "getUserData" .
# Scans node_modules, .git, dist → wastes 50,000 tokens

With bash validation:
grep -r "getUserData" src/
# Automatically suggests focused search → saves 85% tokens
```

## 🎨 Customization

### Adding Your Own Skills
1. Create `.claude/skills/your-skill/SKILL.md`
2. Add trigger rules to `.claude/skills/skill-rules.json`
3. Use the skill-developer skill for guidance

### Modifying Bash Validation
Edit `.claude/hooks/validate-bash.sh` to adjust blocked patterns:
```bash
BLOCKED="node_modules|\.env|__pycache__|\.git/|dist/|build/"
# Add your own patterns
```

### Creating Custom Agents
Add markdown files to `.claude/agents/` following the pattern in existing agents.

## 📊 What You Save

**Token Usage Reduction:**
- 85% reduction from bash validation
- Focused skill activation (only relevant skills load)
- Progressive disclosure (main skills <500 lines)

**Development Speed:**
- Auto-activation (no manual skill invocation)
- Specialized agents for complex tasks
- Slash commands for common workflows

## 🔗 Credits

Based on:
- [Claude Code Infrastructure Showcase](https://github.com/diet103/claude-code-infrastructure-showcase)
- [Claude Code Usage Limit Hack](https://www.reddit.com/r/ClaudeAI/comments/1oh95lh/claude_code_usage_limit_hack/)

## 📄 License

MIT License - Feel free to use and modify for your projects.

## 🆘 Support

If hooks aren't activating:
1. ✅ Verify settings.json was copied
2. ✅ Run `npm install` in .claude/hooks
3. ✅ Run `chmod +x .claude/hooks/*.sh`
4. ✅ Check for conflicting settings.local.json

For skill development guidance, activate the `skill-developer` skill by mentioning "create a skill" or "modify skill-rules.json".

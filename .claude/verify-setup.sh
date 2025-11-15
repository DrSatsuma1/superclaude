#!/bin/bash
# Claude Code Infrastructure Setup Verification Script
# Run this after copying .claude to your project

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Claude Code Infrastructure Setup Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: settings.json exists
echo "📋 Check 1: settings.json exists"
if [ -f ".claude/settings.json" ]; then
    echo "   ✅ settings.json found"
else
    echo "   ❌ settings.json NOT FOUND"
    echo "      Fix: cp -r /path/to/superclaude/.claude ."
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 2: Hooks are executable
echo "🔧 Check 2: Hooks are executable"
HOOK_COUNT=0
NON_EXEC_COUNT=0
for hook in .claude/hooks/*.sh; do
    if [ -f "$hook" ]; then
        HOOK_COUNT=$((HOOK_COUNT + 1))
        if [ ! -x "$hook" ]; then
            echo "   ❌ $(basename $hook) is NOT executable"
            NON_EXEC_COUNT=$((NON_EXEC_COUNT + 1))
        fi
    fi
done

if [ $NON_EXEC_COUNT -eq 0 ] && [ $HOOK_COUNT -gt 0 ]; then
    echo "   ✅ All $HOOK_COUNT hooks are executable"
elif [ $NON_EXEC_COUNT -gt 0 ]; then
    echo "   ❌ $NON_EXEC_COUNT hooks are not executable"
    echo "      Fix: chmod +x .claude/hooks/*.sh"
    ERRORS=$((ERRORS + 1))
else
    echo "   ⚠️  No hook scripts found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check 3: Node modules installed
echo "📦 Check 3: Hook dependencies installed"
if [ -d ".claude/hooks/node_modules" ]; then
    if [ -d ".claude/hooks/node_modules/tsx" ]; then
        echo "   ✅ Dependencies installed (tsx found)"
    else
        echo "   ⚠️  node_modules exists but tsx not found"
        echo "      Fix: cd .claude/hooks && npm install"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ❌ node_modules NOT FOUND"
    echo "      Fix: cd .claude/hooks && npm install"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 4: Critical hooks registered in settings.json
echo "⚙️  Check 4: Hooks registered in settings.json"
if [ -f ".claude/settings.json" ]; then
    if grep -q "UserPromptSubmit" .claude/settings.json; then
        echo "   ✅ UserPromptSubmit hook registered"
    else
        echo "   ⚠️  UserPromptSubmit not found in settings.json"
        WARNINGS=$((WARNINGS + 1))
    fi

    if grep -q "PreToolUse" .claude/settings.json; then
        echo "   ✅ PreToolUse (bash validation) registered"
    else
        echo "   ⚠️  PreToolUse not found in settings.json"
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo ""

# Check 5: Skills directory structure
echo "📚 Check 5: Skills directory structure"
if [ -d ".claude/skills" ]; then
    SKILL_COUNT=$(find .claude/skills -maxdepth 1 -type d | wc -l)
    SKILL_COUNT=$((SKILL_COUNT - 1))  # Subtract the skills directory itself

    if [ -f ".claude/skills/skill-rules.json" ]; then
        echo "   ✅ skill-rules.json found"
        echo "   ✅ $SKILL_COUNT skill directories found"
    else
        echo "   ❌ skill-rules.json NOT FOUND"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ Skills directory NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check 6: settings.local.json conflicts
echo "🔀 Check 6: settings.local.json conflicts"
if [ -f ".claude/settings.local.json" ]; then
    if grep -q '"hooks"' .claude/settings.local.json 2>/dev/null; then
        echo "   ⚠️  settings.local.json has hooks defined"
        echo "      This may override settings.json hooks"
        echo "      Review and merge if needed"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   ✅ settings.local.json exists but no hook conflicts"
    fi
else
    echo "   ✅ No settings.local.json (no conflicts)"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! Infrastructure is ready."
    echo ""
    echo "Next steps:"
    echo "  1. Open this project in Claude Code"
    echo "  2. Try: 'Debug my React components'"
    echo "  3. Try: 'Test my API routes'"
    echo "  4. Skills will auto-activate!"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Setup complete with $WARNINGS warning(s)"
    echo "   Infrastructure will work but review warnings above"
else
    echo "❌ Setup incomplete: $ERRORS error(s), $WARNINGS warning(s)"
    echo ""
    echo "Quick fix commands:"
    echo "  chmod +x .claude/hooks/*.sh"
    echo "  cd .claude/hooks && npm install"
    echo ""
    echo "If settings.json missing, recopy:"
    echo "  cp -r /path/to/superclaude/.claude ."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

#!/usr/bin/env bash
# Gathers current dev context for chat AI prompt enrichment
SERVER="http://127.0.0.1:3334"

# Python launcher — Windows installs usually expose `python`, not `python3`
PYTHON="$(command -v python3 || command -v python)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Current context:"

# Git branch (project dir first, then home as fallback)
for dir in "$PROJECT_DIR" "$HOME"; do
    BRANCH=$(cd "$dir" && git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        LAST_COMMIT=$(cd "$dir" && git log --oneline -1 2>/dev/null)
        echo "- Branch: $BRANCH"
        echo "- Last commit: $LAST_COMMIT"
        RECENT=$(cd "$dir" && git diff --name-only HEAD~1 2>/dev/null | head -3 | sed 's/^/- Changed: /')
        [ -n "$RECENT" ] && echo "$RECENT"
        break
    fi
done

# Active agents
AGENTS=$(curl -sf "$SERVER/roster" 2>/dev/null | "$PYTHON" -c "
import sys,json
d=json.load(sys.stdin)
agents=d.get('activeAgents',[])
if agents:
    for a in agents[:5]:
        print(f\"- Agent: {a.get('name','?')} ({a.get('role','?')}) — {a.get('task','')[:40]}\")
else:
    print('- No active agents')
" 2>/dev/null)
echo "$AGENTS"

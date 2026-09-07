#!/usr/bin/env bash
# =============================================================================
# install-hooks.sh — Add Agent Office hook to ~/.claude/settings.json
#
# This script:
#   1. Backs up the existing settings file
#   2. Adds PreToolUse and PostToolUse hook entries that run agent-tracker.sh
#      (PreToolUse drives agent_spawned / working status, PostToolUse the
#      completions — you want both)
#   3. Prints next steps
#
# Usage:
#   bash hooks/install-hooks.sh
# =============================================================================

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER_SCRIPT="$SCRIPT_DIR/agent-tracker.sh"

# Python launcher — Windows installs usually expose `python`, not `python3`
PYTHON="$(command -v python3 || command -v python)"

# Build the hook command.
# On Windows (Git Bash) Claude Code may execute hooks via cmd.exe/PowerShell,
# which cannot resolve POSIX paths like /d/Workspace/... or find `bash` on
# PATH — so emit absolute Windows paths for both bash.exe and the script.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        BASH_WIN="$(cygpath -w "$(command -v bash)")"
        TRACKER_WIN="$(cygpath -w "$TRACKER_SCRIPT")"
        HOOK_COMMAND="\"$BASH_WIN\" \"$TRACKER_WIN\""
        ;;
    *)
        HOOK_COMMAND="bash \"$TRACKER_SCRIPT\""
        ;;
esac

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║    Agent Office — Hook Installer          ║${RESET}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Validate tracker script exists and is executable
# ---------------------------------------------------------------------------
if [ ! -f "$TRACKER_SCRIPT" ]; then
    echo -e "${RED}[error]${RESET} Tracker script not found: $TRACKER_SCRIPT"
    echo "        Make sure you run this from the agent-office project directory."
    exit 1
fi

chmod +x "$TRACKER_SCRIPT"
echo -e "${GREEN}[ok]${RESET} Tracker script: $TRACKER_SCRIPT"

# ---------------------------------------------------------------------------
# Ensure ~/.claude directory exists
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$SETTINGS_FILE")"

# ---------------------------------------------------------------------------
# Create settings file if it does not exist
# ---------------------------------------------------------------------------
if [ ! -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}[info]${RESET} Creating $SETTINGS_FILE"
    echo '{}' > "$SETTINGS_FILE"
fi

# ---------------------------------------------------------------------------
# Backup existing settings
# ---------------------------------------------------------------------------
BACKUP_FILE="${SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$SETTINGS_FILE" "$BACKUP_FILE"
echo -e "${GREEN}[ok]${RESET} Backup saved: $BACKUP_FILE"

# ---------------------------------------------------------------------------
# Check if the hook is already installed
# ---------------------------------------------------------------------------
if grep -q "agent-tracker.sh" "$SETTINGS_FILE" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}[info]${RESET} Agent Office hook is already installed in $SETTINGS_FILE"
    echo ""
    echo "  To update it, remove the existing entry and re-run this script."
    echo ""
    exit 0
fi

# ---------------------------------------------------------------------------
# Merge hook entry into settings JSON using Python
# ---------------------------------------------------------------------------
echo -e "${CYAN}[...]${RESET} Adding PreToolUse + PostToolUse hooks..."

"$PYTHON" - "$SETTINGS_FILE" "$HOOK_COMMAND" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
hook_command  = sys.argv[2]

with open(settings_path, 'r') as f:
    try:
        settings = json.load(f)
    except json.JSONDecodeError:
        settings = {}

hooks = settings.setdefault('hooks', {})

new_hook_group = {
    "matcher": "",
    "hooks": [
        {
            "type": "command",
            "command": hook_command
        }
    ]
}

for event in ('PreToolUse', 'PostToolUse'):
    event_hooks = hooks.setdefault(event, [])

    # Check if a hook group already contains this command (double safety)
    already_present = any(
        any(h.get('command', '') == hook_command for h in group.get('hooks', []))
        for group in event_hooks
        if isinstance(group, dict)
    )

    if not already_present:
        event_hooks.append(new_hook_group)

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('ok')
PYEOF

echo -e "${GREEN}[ok]${RESET} Hooks added to $SETTINGS_FILE"

# ---------------------------------------------------------------------------
# Print next steps
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}Installation complete!${RESET}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start the Agent Office server:"
echo "       cd $(dirname "$SCRIPT_DIR")"
echo "       npm run server"
echo ""
echo "  2. Start the Agent Office UI:"
echo "       npm run dev           # browser"
echo "       npm run dev:electron  # desktop app"
echo ""
echo "  3. Use Claude Code normally. When you (or Claude) use the Agent"
echo "     tool or any MCP tool, a character will appear in the office."
echo ""
echo "  Hook installed at:"
echo "    $SETTINGS_FILE"
echo ""
echo "  Tracker script:"
echo "    $TRACKER_SCRIPT"
echo ""
echo -e "${YELLOW}Note:${RESET} The server must be running on port 3334 for events to appear."
echo "  If the server is not running, the hook exits silently — no errors."
echo ""

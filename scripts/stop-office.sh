#!/usr/bin/env bash
# =============================================================================
# stop-office.sh — Shut down all Agent Office processes
#
# Stops:
#   1. Chat watcher (bash background process)
#   2. WebSocket/HTTP server (port 3334)
#   3. Vite dev server (port 3333)
#
# Usage:
#   bash scripts/stop-office.sh
#
# Works on macOS, Linux, and Windows (Git Bash).
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║    Agent Office — Shutting Down            ║${RESET}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${RESET}"
echo ""

STOPPED=0

# Find PIDs listening on a port — lsof on macOS/Linux, netstat on Windows
# (Git Bash has no lsof, but Windows netstat lists the owning PID)
port_pids() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -ti :"$1" 2>/dev/null || true
    else
        netstat -ano 2>/dev/null | awk -v port=":$1" '
            $1 == "TCP" && $2 ~ port "$" && $4 == "LISTENING" { print $5 }
        ' | sort -u
    fi
}

# Terminate a PID — `kill` handles MSYS processes (the chat watcher), taskkill
# handles native ones (node.exe). Try kill first on Windows, fall back to
# taskkill. (`//F` dodges MSYS path conversion of `/F`.)
kill_pid() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            kill "$1" 2>/dev/null || taskkill //F //PID "$1" >/dev/null 2>&1 || true
            ;;
        *)
            kill "$1" 2>/dev/null || true
            ;;
    esac
}

# Check whether a PID is alive — MSYS pids and native Windows pids live in
# different pid spaces, so on Windows check both
pid_alive() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            kill -0 "$1" 2>/dev/null && return 0
            tasklist //FI "PID eq $1" 2>/dev/null | grep -q "$1"
            ;;
        *)
            kill -0 "$1" 2>/dev/null
            ;;
    esac
}

# 1. Chat watcher
PID_FILE="$HOME/.agent-office/chat-watcher.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if pid_alive "$PID"; then
        kill_pid "$PID"
        echo -e "${GREEN}[ok]${RESET} Chat watcher stopped (pid $PID)"
        STOPPED=$((STOPPED + 1))
    else
        echo -e "${YELLOW}[skip]${RESET} Chat watcher not running"
    fi
    rm -f "$PID_FILE"
else
    echo -e "${YELLOW}[skip]${RESET} No chat watcher pid file"
fi

# 2. Server on port 3334
SERVER_PIDS=$(port_pids 3334)
if [ -n "$SERVER_PIDS" ]; then
    for pid in $SERVER_PIDS; do kill_pid "$pid"; done
    echo -e "${GREEN}[ok]${RESET} Server stopped (port 3334)"
    STOPPED=$((STOPPED + 1))
else
    echo -e "${YELLOW}[skip]${RESET} Server not running on port 3334"
fi

# 3. Vite on port 3333
VITE_PIDS=$(port_pids 3333)
if [ -n "$VITE_PIDS" ]; then
    for pid in $VITE_PIDS; do kill_pid "$pid"; done
    echo -e "${GREEN}[ok]${RESET} Vite dev server stopped (port 3333)"
    STOPPED=$((STOPPED + 1))
else
    echo -e "${YELLOW}[skip]${RESET} Vite not running on port 3333"
fi

echo ""
if [ "$STOPPED" -gt 0 ]; then
    echo -e "${GREEN}Office closed. $STOPPED process(es) stopped.${RESET}"
else
    echo -e "${YELLOW}Nothing was running.${RESET}"
fi
echo ""

#!/usr/bin/env bash
# notify.sh — Desktop notification, cross-platform
#   macOS:   osascript
#   Windows: PowerShell balloon tip (renders as a toast on Win 10/11)
#   Linux:   notify-send (if available)
TITLE="${1:-Agent Office}"
MSG="${2:-Something happened}"

case "$(uname -s)" in
    Darwin)
        osascript -e "display notification \"$MSG\" with title \"$TITLE\"" 2>/dev/null
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Pass title/message via env vars to sidestep PowerShell quoting hell
        NOTIFY_TITLE="$TITLE" NOTIFY_MSG="$MSG" powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
            Add-Type -AssemblyName System.Windows.Forms
            $n = New-Object System.Windows.Forms.NotifyIcon
            $n.Icon = [System.Drawing.SystemIcons]::Information
            $n.Visible = $true
            $n.ShowBalloonTip(5000, $env:NOTIFY_TITLE, $env:NOTIFY_MSG, [System.Windows.Forms.ToolTipIcon]::Info)
            Start-Sleep -Seconds 6
            $n.Dispose()
        ' >/dev/null 2>&1
        ;;
    *)
        command -v notify-send >/dev/null 2>&1 && notify-send "$TITLE" "$MSG" 2>/dev/null
        ;;
esac

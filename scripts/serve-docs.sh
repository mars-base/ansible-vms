#!/usr/bin/env bash
# serve-docs.sh — run the Hugo docs site locally in the background.
# Usage: serve-docs.sh [start|stop|restart|status|log] [PORT]
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../site" && pwd)"
PORT="${2:-${PORT:-1313}}"
PID_FILE="${PID_FILE:-/tmp/ansible-vms-docs.pid}"
LOG_FILE="${LOG_FILE:-/tmp/ansible-vms-docs.log}"

running() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }

case "${1:-start}" in
    start)
        if running; then
            echo "already running (pid $(cat "$PID_FILE"), http://localhost:$PORT)"
            exit 0
        fi
        if ! command -v hugo &>/dev/null; then
            echo "ERROR: hugo not found. Install Hugo extended >= 0.168.0" >&2
            exit 1
        fi
        cd "$SITE_DIR"
        nohup hugo server --disableFastRender --port "$PORT" >"$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "started (pid $(cat "$PID_FILE")) — http://localhost:$PORT"
        echo "log: $LOG_FILE"
        ;;
    restart)
        if running; then
            kill "$(cat "$PID_FILE")"
            rm -f "$PID_FILE"
            for _ in $(seq 1 20); do
                ss -tln 2>/dev/null | grep -q ":$PORT " || break
                sleep 0.2
            done
            echo "stopped"
        fi
        exec "$0" start "$PORT"
        ;;
    stop)
        if running; then
            kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
            echo "stopped"
        else
            echo "not running"; rm -f "$PID_FILE"
        fi
        ;;
    status)
        if running; then
            echo "running (pid $(cat "$PID_FILE")) — http://localhost:$PORT"
        else
            echo "not running"
        fi
        ;;
    log)
        tail -n "${LOG_LINES:-40}" "$LOG_FILE"
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|status|log] [PORT]" >&2
        exit 2
        ;;
esac

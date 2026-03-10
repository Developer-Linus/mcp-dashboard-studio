#!/usr/bin/env bash

set -e

APP_ENTRY="main.jac"
MCP_PORT=3001
TRANSPORT="sse"

echo ""
echo "=============================================="
echo "🚀 Jac MCP Playground – Development Environment"
echo "=============================================="
echo ""

# Detect virtual environment
if [ -d ".venv" ]; then
    echo "🔧 Activating virtual environment (.venv)"
    source .venv/bin/activate
else
    echo "❌ .venv not found."
    echo "Run: python -m venv .venv"
    exit 1
fi

# Check jac installation
if ! command -v jac >/dev/null 2>&1; then
    echo "❌ 'jac' command not found in the virtual environment."
    echo "Install Jaseci first."
    exit 1
fi

echo "✅ Jac detected:"
jac --version
echo ""

# Verify jac-mcp plugin exists
if ! jac --version | grep -q "jac-mcp"; then
    echo "❌ jac-mcp plugin not installed."
    echo "Run: pip install jac-mcp"
    exit 1
fi

# Free MCP port if already used
if lsof -ti :$MCP_PORT >/dev/null; then
    echo "⚠ Port $MCP_PORT already in use. Killing process..."
    kill -9 $(lsof -ti :$MCP_PORT)
fi

echo "📡 Starting MCP server"
echo "   Transport: $TRANSPORT"
echo "   Port:      $MCP_PORT"
echo ""

jac mcp --transport $TRANSPORT --port $MCP_PORT &
MCP_PID=$!

echo "✅ MCP server started (PID: $MCP_PID)"
echo ""

sleep 2

echo "🌐 Starting Jac full-stack app"
echo "   Entry: $APP_ENTRY"
echo ""

# Cleanup handler
cleanup() {
    echo ""
    echo "🛑 Stopping MCP server..."
    kill $MCP_PID 2>/dev/null || true
}

trap cleanup EXIT

jac start $APP_ENTRY --dev
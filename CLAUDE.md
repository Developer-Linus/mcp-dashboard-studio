# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development

```bash
# Start both MCP server and Jac full-stack app
./scripts/dev.sh

# Start MCP server manually (streamable-http, port 3001)
jac-mcp serve --transport streamable-http --port 3001

# Start the Jac full-stack app
jac run main.jac
```

### Dependencies

```bash
# Install Python dependencies
uv sync

# Activate virtual environment
source .venv/bin/activate
```

## Architecture

Three-layer design where all layers are written in Jac:

```
Frontend UI (home.cl.jac)
    ↓ walker calls
Backend Walkers (main.jac)
    ↓ service functions
MCP Service Layer (backend/service.jac)
    ↓ JSON-RPC over HTTP
MCP Server (jac-mcp, port 3001)
    ↓ invokes
Jac Compiler tools (validate_jac, format_jac, explain_error)
```

### Layer Responsibilities

- **`main.jac`** — Entry point. Defines three public walkers (`validate_code`, `format_code`, `explain_code_error`) and exports the frontend `app()`.
- **`frontend/home.cl.jac`** — React/JSX UI component with code editor, action buttons, and response panels. Uses Tailwind CSS.
- **`backend/service.jac`** — All MCP communication. Handles session initialization (lazy with caching), JSON-RPC requests, 401 retry on session expiry, and response normalization.
- **`backend/utils.jac`** — Validation helpers for empty inputs and error extraction.

### Response Contract

All service functions return a consistent dict:
```python
{ok: bool, tool: str, data: any, error: str}
```

### MCP Session Management

`service.jac` maintains a module-level `MCP_SESSION_ID` global. Sessions are initialized lazily on first tool call and reused. On 401 responses, the session is cleared and the call is retried once with a fresh session.

### Transport

MCP server uses `streamable-http` transport on `http://localhost:3001/mcp`. The `jac.toml` plugin config and `scripts/dev.sh` both target this URL/port.

## Key Files

| File | Purpose |
|------|---------|
| `main.jac` | Walker definitions + app export |
| `frontend/home.cl.jac` | UI component |
| `backend/service.jac` | MCP client + session logic |
| `backend/utils.jac` | Input validation helpers |
| `jac.toml` | Project config, Vite/Tailwind, MCP plugin |
| `scripts/dev.sh` | Dev startup script |
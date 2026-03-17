# Jac MCP Playground

A focused developer utility that exercises MCP compiler tooling through a Jac-only frontend/back-end stack. The application orchestrates walkers that call MCP tools over the streamable-http transport while keeping the UI unaware of underlying JSON-RPC mechanics—ideal for engineering teams evaluating Jac tooling quality and integrations.

## Capabilities

- **Jac validation** via `validate_jac` to enforce full type checking, declarations, and macros.
- **Code formatting** through `format_jac`, which replaces the editor contents with the normalized output.
- **Error explanation** via `explain_error` to translate compiler diagnostics into actionable guidance.
- **Syntax checking** with `check_syntax` for a quick parse-only pass.
- **Python-to-Jac conversion** using `py_to_jac` to demonstrate cross-language translation.
- **AST generation** using `get_ast` (tree output) for structural insight.

## Architecture

1. **Frontend (`frontend/home.cl.jac`)** – Jac JSX interface with editor, response pane, Python converter, and action buttons. It spawns walkers and renders normalized reports/AST outputs.
2. **Walkers (`main.jac`)** – Each walker performs minimal validation, delegates to a backend service, and reports results for the UI.
3. **Service layer (`backend/service.jac`)** – Manages streamable-http session lifecycle, wraps MCP tool calls (`validate_code_service`, `format_code_service`, etc.), and flattens the JSON-RPC content envelope into a consistent response shape.
4. **Utilities (`backend/utils.jac`)** – Common helpers to fabricate empty-input responses and extract the first compiler error message for UI hints.

## System Architecture & Design

- **Three-layer separation** keeps UI, API walkers, and MCP access decoupled. The frontend only spawns walkers; all tool invocation logic lives in backend services, preserving transport isolation.
- **Streamable HTTP transport** is handled centrally in `backend/service.jac`, covering MCP session init, `tools/call`, retry on 401, and JSON parsing of the result envelope.
- **Normalized response shape** (`{ok, tool, data, error}`) ensures all UI paths can handle success/failure uniformly without bespoke parsing per tool.
- **Utility helpers** provide consistent empty-input guards and error extraction so UI notices remain meaningful even when MCP responses are incomplete.

```
Frontend UI (home.cl.jac)
        │
        ▼
   Walkers (main.jac)
        │
        ▼
Service layer (backend/service.jac)
        │
        ▼
   MCP Server (jac-mcp)
```

## Running the Playground

### Prerequisites

- Jac compiler with the `jac-mcp` plugin installed in `.venv` (verify via `jac --version`).
- Port 3001 available for the MCP server.

### Startup

1. Activate the virtual environment: `source .venv/bin/activate` (create with `python -m venv .venv` if absent).
2. Launch both services with `./scripts/dev.sh`, which:
   - Frees port 3001 if in use.
   - Starts `jac mcp --transport streamable-http --port 3001`.
   - Runs `jac start main.jac --dev` for the full-stack app.
3. Open the provided browser URL, input Jac or Python code, and interact with the buttons—each action spawns a walker and displays the MCP response.

## Known Issues

- `validate_jac` and `check_syntax` currently report `ok: true` even for invalid Jac snippets on the MCP server, so the UI can’t automatically reject bad code until the server is fixed.
- `py_to_jac` responses omit a populated `jac_code` field, meaning conversions never appear in the Python converter panel.
- `list_examples` returns an empty list, so example fetching is unavailable.
- The service layer now assumes the streamable-http transport (the previous SSE code paths are inactive).

## Next Steps

1. Coordinate with the MCP toolchain owners so invalid inputs yield `valid: false` responses and Python conversions include actual Jac output.
2. Add UI detection for anomalous responses (e.g., `ok: true` with compiler errors or empty translation data) so practitioners see warnings instead of trusting faulty feedback.
3. Expand the frontend with sample snippets, syntax highlighting, and multi-file validation once `list_examples` and other MCP tools resume normal behavior.

## Support Contacts

- Report MCP transport or tool issues through the `jac-mcp` repository or issue tracker.

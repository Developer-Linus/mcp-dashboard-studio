# Jac MCP Playground

A focused developer tool for **validating, formatting, and explaining Jac code** using the **Jac Model Context Protocol (MCP) server**.

This project demonstrates how a **Jac full-stack application** can interact with the **jac-mcp server** to provide compiler assistance capabilities inside a simple developer UI.

The application provides three core capabilities:

* **Validate Jac code**
* **Format Jac code**
* **Explain compiler errors**

The system is implemented using a **pure Jac stack architecture**, with no external application frameworks such as Node.js or FastAPI.

---

# Overview

Jac MCP Playground provides a minimal but practical environment for interacting with the Jac compiler through MCP tools.

Users can:

1. Paste or write Jac code
2. Run validation against the compiler
3. Automatically format code
4. Receive explanations for compiler errors

The system acts as a **thin orchestration layer** between a frontend UI and the MCP tool server.

---

# System Architecture

The system follows a **three-layer architecture**.

```
Frontend UI
      │
      │ spawn walkers
      ▼
Backend API walkers
      │
      │ call services
      ▼
MCP Service Layer
      │
      │ JSON-RPC
      ▼
jac-mcp Server
      │
      ▼
Jac Compiler Toolchain
```

---

## Architecture Layers

### 1. Frontend Layer

Implemented using **Jac client components**.

Responsibilities:

* Display code editor
* Provide developer actions
* Display results and errors
* Spawn backend walkers

Location:

```
frontend/home.cl.jac
```

The frontend **does not directly communicate with MCP**.

Instead it spawns backend walkers.

Example flow:

```
UI action
    ↓
spawn validate_code walker
```

---

### 2. Backend API Layer

Implemented using **Jac walkers as API endpoints**.

Responsibilities:

* Validate inputs
* Call service layer
* Return structured reports

Location:

```
backend/api.jac
```

Example walker:

```
validate_code
format_code
explain_code_error
```

Each walker:

1. receives input
2. calls service
3. reports normalized response

---

### 3. Service Layer

Responsible for **communication with the MCP server**.

Location:

```
backend/service.jac
```

Responsibilities:

* bootstrap SSE session
* send JSON-RPC tool calls
* normalize MCP responses
* return consistent data structure

Service functions:

```
validate_code_service
format_code_service
explain_code_error_service
```

These functions internally call:

```
call_mcp_tool()
```

---

### 4. MCP Server

External system.

Started using:

```
jac mcp
```

Responsibilities:

* expose compiler tools
* validate Jac code
* format Jac code
* explain errors

Tools used:

```
validate_jac
format_jac
explain_error
```

---

# Transport Design

## Intended Transport

```
streamable-http
```

The application was originally designed to communicate with MCP through the **streamable HTTP transport**, which exposes a single endpoint:

```
POST /mcp
```

However, a runtime issue currently prevents the transport from starting:

```
StreamableHTTPServerTransport.__init__()
unexpected keyword argument 'mcp_endpoint'
```

---

## Temporary Transport

Because of this issue, the project temporarily uses:

```
SSE transport
```

SSE transport works through two endpoints:

```
GET  /sse
POST /messages/?session_id=...
```

Flow:

```
1. connect to /sse
2. read endpoint event
3. extract message endpoint
4. POST tool calls to message endpoint
```

This logic is implemented in:

```
backend/service.jac
```

---

# Design Principles

This project intentionally follows several design principles.

---

## 1. Pure Jac Stack

The system avoids external backend frameworks.


All backend logic is implemented using:

```
Jac walkers
Jac modules
Jac service functions
```

---

## 2. Transport Isolation

Transport details are isolated in:

```
backend/service.jac
```

This ensures:

```
frontend
api walkers
```

remain independent from MCP transport changes.

When `streamable-http` becomes available again, only the service layer must change.

---

## 3. Stable Response Contract

All service responses follow a normalized format:

```
{
  "ok": bool,
  "tool": str,
  "data": dict,
  "error": dict
}
```

Benefits:

* predictable frontend behavior
* simplified error handling
* stable API surface

---

## 4. Thin Frontend

Frontend responsibilities are intentionally minimal.

The frontend only:

```
spawn walker
display result
```

It does not know about:

```
MCP
JSON-RPC
transport
compiler tools
```

---

# Project Structure

```
.
├── README.md
├── __init__.jac
│
├── backend
│   ├── __init__.jac
│   ├── api.jac
│   ├── service.jac
│   ├── types.jac
│   └── utils.jac
│
├── frontend
│   └── home.cl.jac
│
├── jac.toml
├── main.jac
├── pyproject.toml
│
├── scripts
│   └── dev.sh
│
├── styles.css
└── uv.lock
```

---

## backend/

Contains all backend application logic.

### api.jac

Defines walker endpoints.

Examples:

```
validate_code
format_code
explain_code_error
```

---

### service.jac

Handles MCP communication.

Responsibilities:

```
SSE session bootstrap
JSON-RPC tool invocation
response normalization
```

---

### utils.jac

Helper utilities used across backend modules.

---

---

## frontend/

Contains the client UI.

### home.cl.jac

Main user interface.

Features:

* Jac editor
* validation button
* format button
* explain error button
* result panel
* error inspector

---

## scripts/

Contains development tooling.

### dev.sh

Starts both:

```
jac-mcp server
Jac full-stack app
```

Usage:

```
./scripts/dev.sh
```

---

## main.jac

Application entry point.

Defines:

```
client app routing
```

---

## jac.toml

Project configuration.

Includes:

* client plugin configuration
* tailwind integration
* MCP configuration

---

# Development Workflow

## Start Development Environment

```
./scripts/dev.sh
```

This script:

1. activates `.venv`
2. starts MCP server
3. starts Jac application

---

## Manual Startup

Start MCP:

```
jac mcp --transport sse --port 3001
```

Start app:

```
jac start main.jac
```

---

# Example Workflow

1. User writes Jac code

```
node Farm {
    has name: str;
}
```

1. Click **Validate**

2. Walker executes:

```
validate_code
```

1. Service calls MCP:

```
validate_jac
```

1. Result returned to UI

---

# Future Improvements

## Streamable HTTP Support

When MCP transport issue is resolved:

* remove SSE bootstrap logic
* replace with `/mcp` endpoint calls

---

## Syntax Highlighting

Integrate a proper Jac syntax editor.

---

## Example Snippets

Provide sample Jac programs.

---

## Multi-file Validation

Allow validating entire Jac projects instead of single snippets.

---

# Why This Project Matters

This project demonstrates how Jac can be used to build:

* developer tooling
* language services
* compiler assistants
* graph-native full-stack systems

using **only the Jac ecosystem**.

---

# License

MIT License.

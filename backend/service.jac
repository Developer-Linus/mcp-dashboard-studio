import requests;
import json;
import uuid;

# Streamable HTTP MCP endpoint exposed by `jac mcp --transport streamable-http`.
# Use the canonical endpoint with trailing slash to avoid redirect ambiguity.
glob MCP_URL = "http://127.0.0.1:3001/mcp/";

# The MCP server is session-oriented for streamable-http.
# After a successful `initialize` request, the server returns an `mcp-session-id`
# header that must be sent on subsequent requests.
#
# We cache it in memory so the backend does not re-initialize the session
# for every single tool call.
glob MCP_SESSION_ID: str | None = None;


"""
Send a JSON-RPC request to the MCP endpoint with optional session header.

Why this exists:
- It centralizes request headers and timeout behavior.
- It avoids duplicating the same `requests.post(...)` logic.
- It makes the initialize / initialized / tools/call lifecycle clearer.
"""
def _post_json(payload: dict, session_id: str | None = None) -> any {
    headers = {
        # For streamable-http, the client should be ready to accept either:
        # - standard JSON
        # - SSE/event-stream
        #
        # Even if the current server returns JSON for these requests,
        # advertising support for both keeps the client aligned with the transport.
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",

    };

    if session_id is not None {
        # This is mandatory after initialization for this server.
        headers["Mcp-Session-Id"] = session_id;
    }

    return requests.post(MCP_URL, json=payload, timeout=20, headers=headers);
}


"""
Initialize an MCP session once and cache the returned session ID.

Why this exists:
- Streamable HTTP in this server is stateful.
- Tool calls without `Mcp-Session-Id` fail with "Missing session ID".
- The correct lifecycle is:
    1. initialize
    2. store session ID
    3. send tools/call requests with that session ID

Why we do lazy initialization:
- The service may be imported before the MCP server is running.
- Initializing only when the first tool call happens avoids startup fragility.
"""
def _initialize_mcp_session() -> str {
    global MCP_SESSION_ID;

    # Reuse the existing session if we already initialized successfully.
    if MCP_SESSION_ID is not None {
        return MCP_SESSION_ID;
    }

    # Every JSON-RPC request should have its own unique ID.
    # This becomes important when debugging concurrent or interleaved requests.
    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "initialize",
        "params": {
            # This should match the protocol version expected by the server.
            "protocolVersion": "2025-03-26",
            # Client capabilities can be expanded later if needed.
            # For now, we keep them minimal because this service only needs
            # tool invocation and standard MCP session behavior.
            "capabilities": {},
            # Client metadata is useful for debugging server logs and future tracing.
            "clientInfo": {"name": "jac-playground", "version": "0.1.0"}
        }
    };

    resp = _post_json(payload);

    # Initialization failure is a hard failure.
    # Without a valid session, no tool call can succeed.
    if resp.status_code >= 400 {
        raise Exception(f"Failed to initialize MCP session: {resp.text}") ;
    }

    # The server communicates session state via response headers, not JSON body.
    session_id = resp.headers.get("mcp-session-id");
    if not session_id {
        raise Exception("MCP server did not return mcp-session-id") ;
    }

    # Some MCP servers require the standard initialized notification after
    # the initialize handshake completes. Without this, later tool calls may
    # be rejected even if a session ID was returned successfully.
    initialized_payload = {
        "jsonrpc": "2.0",
        "method": "notifications/initialized",
        "params": {}
    };

    initialized_resp = _post_json(initialized_payload, session_id=session_id);

    if initialized_resp.status_code >= 400 {
        raise Exception(
            f"Failed to send MCP initialized notification: {initialized_resp.text}"
        ) ;
    }

    MCP_SESSION_ID = session_id;
    return MCP_SESSION_ID;
}


"""
Extract and normalize the actual tool result from the MCP JSON-RPC envelope.

Important observation from jac-mcp:
- The server does NOT return tool output directly as:
    {"result": {"valid": true, ...}}

- Instead it returns a content envelope like:
    {
      "result": {
        "content": [
          {
            "type": "text",
            "text": "{ ...json string... }"
          }
        ],
        "isError": false
      }
    }

So we must:
1. inspect `result`
2. read the first content item
3. take its `text`
4. attempt to parse that text as JSON
"""
def _extract_tool_result(body: dict) -> dict {
    # Standard JSON-RPC error at protocol level.
    # This means the tool call failed before we got a normal result envelope.
    if "error" in body {
        return {"ok": False, "data": {}, "error": body["error"]};
    }

    result = body.get("result", {});
    is_error = result.get("isError", False);
    content = result.get("content", []);

    # If the server returns a result envelope without content,
    # fall back to returning the raw result so the caller still has
    # something useful for debugging.
    if not content {
        return {
            "ok": not is_error,
            "data": result,
            "error": {} if not is_error else {"message": "Tool returned no content"}
        };
    }

    # jac-mcp currently returns text content, and that text itself may be JSON.
    first_item = content[0];
    text_value = first_item.get("text", "");

    try {
        # Best case:
        # the tool returned structured JSON serialized as a string.
        # Example:
        #   {"valid": true, "errors": [], "warnings": []}
        parsed_data = json.loads(text_value);
    } except Exception {
        # Fallback:
        # not every tool is guaranteed to return JSON text.
        # Some tools may return explanatory prose, formatted source code,
        # or mixed human-readable output.
        parsed_data = {"raw_text": text_value};
    }

    return {
        "ok": not is_error,
        "data": parsed_data,
        "error": {} if not is_error else {"message": "Tool returned error output"}
    };
}


"""
Call an MCP tool through the streamable-http transport.

Design goals:
- initialize once, then reuse the session
- hide MCP protocol details from the rest of the app
- always return one stable application-level response shape:
    {
      "ok": bool,
      "tool": str,
      "data": dict,
      "error": dict
    }

Why this wrapper matters:
- The frontend and API layer should not need to know about JSON-RPC,
  session IDs, or MCP content envelopes.
- This function acts as the protocol boundary.
"""
def _call_mcp_tool_once(tool_name: str, args: dict, session_id: str) -> dict {
    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "tools/call",
        "params": {"name": tool_name, "arguments": args}
    };

    resp = _post_json(payload, session_id=session_id);

    # Transport / HTTP failure.
    # We still try to decode JSON because MCP servers often return structured
    # error bodies even when the HTTP status is non-2xx.
    if resp.status_code >= 400 {
        try {
            body = resp.json();
        } except Exception {
            body = {"message": resp.text};
        }

        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": {"message": f"MCP HTTP error {resp.status_code}", "details": body},
            "status_code": resp.status_code
        };
    }

    # For the currently observed jac-mcp response shape, application/json is returned.
    # If the server later returns SSE for some cases, this function is where that
    # support should be added cleanly.
    body = resp.json();
    extracted = _extract_tool_result(body);

    return {
        "ok": extracted["ok"],
        "tool": tool_name,
        "data": extracted["data"],
        "error": extracted["error"],
        "status_code": resp.status_code
    };
}


"""
Call an MCP tool through the streamable-http transport.

Design goals:
- initialize once, then reuse the session
- hide MCP protocol details from the rest of the app
- always return one stable application-level response shape:
    {
      "ok": bool,
      "tool": str,
      "data": dict,
      "error": dict
    }

Why this wrapper matters:
- The frontend and API layer should not need to know about JSON-RPC,
  session IDs, or MCP content envelopes.
- This function acts as the protocol boundary.
"""
def call_mcp_tool(tool_name: str, args: dict) -> dict {
    global MCP_SESSION_ID;

    try {
        session_id = _initialize_mcp_session();
        result = _call_mcp_tool_once(tool_name, args, session_id);

        # If the cached session became stale, clear it, reinitialize,
        # and retry exactly once.
        if "status_code" in result and result["status_code"] == 401 {
            MCP_SESSION_ID = None;
            session_id = _initialize_mcp_session();
            result = _call_mcp_tool_once(tool_name, args, session_id);
        }

        if "status_code" in result {
            del result["status_code"];
        }

        return result;
    } except Exception as e {
        # This is the outermost safety net.
        # We keep the returned shape stable so callers do not have to wrap this
        # function again just to handle exceptions.
        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": {"message": str(e)}
        };
    }
}


"""
Validate Jac code using the full compiler/type-check pipeline.

Expected success data shape:
{
  "valid": true,
  "errors": [],
  "warnings": []
}
"""
def validate_code_service(code: str) -> dict {
    return call_mcp_tool("validate_jac", {"code": code});
}


"""
Format Jac code according to the server's formatter.

Typical success data shape:
{
  "formatted": "...",
  "changed": true
}
"""
def format_code_service(code: str) -> dict {
    return call_mcp_tool("format_jac", {"code": code});
}


"""
Explain a Jac compiler/runtime error in a more user-friendly way.

Typical success data shape may include:
- title
- explanation
- suggestion
- example
- docs_uri
"""
def explain_code_error_service(error_message: str) -> dict {
    return call_mcp_tool("explain_error", {"error_message": error_message});
}


"""
Check Jac code for syntax errors using the lightweight syntax checker.

Expected success data shape:
{
  "valid": true,
  "errors": []
}
"""
def check_syntax_service(code: str) -> dict {
    return call_mcp_tool("check_syntax", {"code": code});
}


"""
Translate Python source code to equivalent Jac code.

Expected success data shape:
{
  "jac_code": "...",
  "notes": "..."
}
"""
def py_to_jac_service(python_code: str) -> dict {
    return call_mcp_tool("py_to_jac", {"python_code": python_code});
}


"""
List available Jac example files, optionally filtered by category.

Expected success data shape:
{
  "examples": [{"name": "...", "category": "...", "description": "..."}, ...]
}
"""
def list_examples_service(category: str | None = None) -> dict {
    args: dict = {};
    if category is not None {
        args["category"] = category;
    }
    return call_mcp_tool("list_examples", args);
}


"""
Retrieve the source code of a named Jac example.

Expected success data shape:
{
  "content": "...",
  "name": "..."
}
"""
def get_example_service(name: str) -> dict {
    return call_mcp_tool("get_example", {"name": name});
}


"""
Search the Jac documentation for a query string.

Expected success data shape:
{
  "results": [{"title": "...", "snippet": "...", "uri": "..."}, ...]
}
"""
def search_docs_service(query: str, limit: int | None = None) -> dict {
    args: dict = {"query": query};
    if limit is not None {
        args["limit"] = limit;
    }
    return call_mcp_tool("search_docs", args);
}


"""
Generate the AST for Jac code in either tree or JSON format.

Expected success data shape (tree):
{
  "ast": "..."
}
"""
def get_ast_service(code: str, format: str = "tree") -> dict {
    return call_mcp_tool("get_ast", {"code": code, "format": format});
}

import requests;

glob MCP_URL = "http://127.0.0.1:3001/mcp";

"""
Function to call mcp server with tool name and respective input data
"""
def call_mcp_tool(tool_name: str, args: dict) -> dict {
    try {
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {"name": tool_name, "arguments": args}
        };

        resp = requests.post(MCP_URL, json=payload, timeout=10);
        body = resp.json();

        # HTTP Status error handling
        if resp.status_code >= 400 {
            return {
                "ok": False,
                "tool": tool_name,
                "data": {},
                "error": {
                    "message": f"MCP HTTP error {resp.status_code}",
                    "details": body
                }
            };
        }
        # MCP-level error handling
        if "error" in body {
            return {
                "ok": False,
                "tool": tool_name,
                "data": {},
                "error": body["error"]
            };
        }

        return {"ok": True, "tool": tool_name, "data": body, "error": {},};
    } except Exception as e {
        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": {"message": str(e),}
        };
    }
}

def validate_code_service(code: str) -> dict {
    return call_mcp_tool("validate_jac", {"code": code});
}

def format_code_service(code: str) -> dict {
    return call_mcp_tool("format_jac", {"code": code});
}

def explain_code_error_service(error_message: str) -> dict {
    return call_mcp_tool("explain_error", {"error_message": error_message});
}

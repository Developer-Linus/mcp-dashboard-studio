import requests;

glob SSE_URL = "http://127.0.0.1:3001/sse";
glob BASE_URL = "http://127.0.0.1:3001";
glob MESSAGE_URL = "";

def parse_sse_endpoint(raw_text: str) -> str {
    lines = raw_text.split("\n");

    for line in lines {
        clean = line.strip();

        if clean.startswith("data:") {
            return clean.replace("data:", "").strip();
        }
    }

    return "";
}

def ensure_sse_session() -> dict {
    if MESSAGE_URL != "" {
        return {"ok": True, "message_url": MESSAGE_URL, "error": {}};
    }

    try {
        resp = requests.get(SSE_URL, stream=True, timeout=10);

        if resp.status_code >= 400 {
            return {
                "ok": False,
                "message_url": "",
                "error": {
                    "message": f"SSE bootstrap failed with HTTP {resp.status_code}"
                }
            };
        }

        raw_text = "";

        for chunk in resp.iter_lines(decode_unicode=True) {
            if chunk is None {
                continue;
            }

            raw_text = raw_text + chunk + "\n";

            if "event: endpoint" in raw_text and "data:" in raw_text {
                break;
            }
        }

        endpoint = parse_sse_endpoint(raw_text);

        if endpoint == "" {
            return {
                "ok": False,
                "message_url": "",
                "error": {"message": "Could not extract SSE message endpoint."}
            };
        }

        if endpoint.startswith("http://") or endpoint.startswith("https://") {
            MESSAGE_URL = endpoint;
        } else {
            MESSAGE_URL = BASE_URL + endpoint;
        }

        return {"ok": True, "message_url": MESSAGE_URL, "error": {}};
    } except Exception as e {
        return {"ok": False, "message_url": "", "error": {"message": str(e)}};
    }
}

def call_mcp_tool(tool_name: str, args: dict) -> dict {
    session_result = ensure_sse_session();

    if not session_result["ok"] {
        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": session_result["error"]
        };
    }

    try {
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {"name": tool_name, "arguments": args}
        };

        resp = requests.post(session_result["message_url"], json=payload, timeout=10);
        body = resp.json();

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

        if "error" in body {
            return {
                "ok": False,
                "tool": tool_name,
                "data": {},
                "error": body["error"]
            };
        }

        return {"ok": True, "tool": tool_name, "data": body, "error": {}};
    } except Exception as e {
        return {
            "ok": False,
            "tool": tool_name,
            "data": {},
            "error": {"message": str(e)}
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

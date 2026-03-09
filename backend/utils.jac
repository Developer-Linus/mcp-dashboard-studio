def empty_code_response(tool_name: str) -> dict {
    return {
        "ok": False,
        "tool": tool_name,
        "data": {},
        "error": {"message": "Code input cannot be empty."}
    };
}

def empty_error_message_response() -> dict {
    return {
        "ok": False,
        "tool": "explain_error",
        "data": {},
        "error": {"message": "Error message cannot be empty."}
    };
}

def extract_first_error(result: dict) -> str {
    if not result["ok"] {
        if "error" in result and "message" in result["error"] {
            return result["error"]["message"];
        }
        return "";
    }

    if "data" not in result {
        return "";
    }

    if "result" not in result["data"] {
        return "";
    }

    if "errors" not in result["data"]["result"] {
        return "";
    }

    errors = result["data"]["result"]["errors"];

    if len(errors) == 0 {
        return "";
    }

    first_error = errors[0];

    if "message" in first_error {
        return first_error["message"];
    }

    return "";
}

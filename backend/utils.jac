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
    # If the service call itself failed, prefer the top-level error message.
    if not result["ok"] {
        if "error" in result and "message" in result["error"] {
            return result["error"]["message"];
        }
        return "";
    }

    # Successful service response should place the normalized tool payload
    # directly under `data`.
    if "data" not in result {
        return "";
    }

    payload = result["data"];

    # For validate_jac, compiler errors are expected under `errors`.
    if "errors" in payload and len(payload["errors"]) > 0 {
        first_error = payload["errors"][0];

        if "message" in first_error {
            return first_error["message"];
        }
    }

    return "";
}

import "../styles.css";
sv import from ..backend.api { validate_code, format_code, explain_code_error }


def get_first_report(spawn_result: any) -> dict {
    if spawn_result.reports and spawn_result.reports.length > 0 {
        return spawn_result.reports[0];
    }

    return {
        "ok": False,
        "tool": "unknown",
        "data": {},
        "error": {"message": "No report returned from backend."}
    };
}

def extract_first_validation_error(payload: dict) -> str {
    if "ok" not in payload or not payload["ok"] {
        if "error" in payload and "message" in payload["error"] {
            return payload["error"]["message"];
        }
        return "";
    }

    if "data" not in payload {
        return "";
    }

    data = payload["data"];

    if "result" not in data {
        return "";
    }

    result = data["result"];

    if "errors" not in result {
        return "";
    }

    errors = result["errors"];

    if len(errors) == 0 {
        return "";
    }

    first_error = errors[0];

    if "message" in first_error {
        return first_error["message"];
    }

    return "";
}

def extract_formatted_code(payload: dict) -> str {
    if "ok" not in payload or not payload["ok"] {
        return "";
    }

    if "data" not in payload {
        return "";
    }

    data = payload["data"];

    if "result" not in data {
        return "";
    }

    result = data["result"];

    if "formatted" in result {
        return result["formatted"];
    }

    return "";
}

def pretty_json(value: any) -> str {
    try {
        return JSON.stringify(value, None, 2);
    } except Exception {
        return "{}";
    }
}

def:pub Home() -> JsxElement {
    has code: str = "node Farm {\n"
    "    has name: str;\n"
    "}\n\n"
    "with entry {\n"
    "    farm = root ++> Farm(name=\"Green Valley\");\n"
    "    print(farm.size);\n"
    "}\n";

    has loading: bool = False;
    has active_action: str = "";
    has response: dict = {};
    has error_text: str = "";
    has explain_target: str = "";
    has notice: str = "Paste Jac code, then validate or format it.";

    async def run_validate() -> None {
        loading = True;
        active_action = "validate";
        error_text = "";
        notice = "Validating code...";

        try {
            spawn_result = await root spawn validate_code(code=code);
            payload = get_first_report(spawn_result);
            response = payload;

            first_error = extract_first_validation_error(payload);
            explain_target = first_error;

            if "ok" in payload and payload["ok"] {
                if first_error != "" {
                    notice = "Validation finished with compiler errors.";
                } else {
                    notice = "Validation passed.";
                }
            } else {
                notice = "Validation failed before compiler results were returned.";
                if "error" in payload and "message" in payload["error"] {
                    error_text = payload["error"]["message"];
                }
            }
        } except Exception as e {
            response = {};
            error_text = f"Failed to validate code: {e}";
            notice = "Validation request failed.";
        }

        loading = False;
    }

    async def run_format() -> None {
        loading = True;
        active_action = "format";
        error_text = "";
        notice = "Formatting code...";

        try {
            spawn_result = await root spawn format_code(code=code);
            payload = get_first_report(spawn_result);
            response = payload;

            formatted = extract_formatted_code(payload);

            if formatted != "" {
                code = formatted;
                notice = "Code formatted successfully.";
            } else {
                notice = "Formatting finished, but no formatted output was found.";
            }

            if "ok" not in payload or not payload["ok"] {
                if "error" in payload and "message" in payload["error"] {
                    error_text = payload["error"]["message"];
                }
            }
        } except Exception as e {
            response = {};
            error_text = f"Failed to format code: {e}";
            notice = "Format request failed.";
        }

        loading = False;
    }

    async def run_explain() -> None {
        loading = True;
        active_action = "explain";
        error_text = "";
        notice = "Explaining compiler error...";

        try {
            target_error = explain_target.strip();
            spawn_result = root spawn explain_code_error(error_message=target_error);
            payload = get_first_report(spawn_result);
            response = payload;

            if "ok" in payload and payload["ok"] {
                notice = "Error explanation loaded.";
            } else {
                notice = "Could not generate an explanation.";
                if "error" in payload and "message" in payload["error"] {
                    error_text = payload["error"]["message"];
                }
            }
        } except Exception as e {
            response = {};
            error_text = f"Failed to explain error: {e}";
            notice = "Explain request failed.";
        }

        loading = False;
    }

    return
        <div className="min-h-screen bg-white text-slate-900">
            <div className="mx-auto max-w-7xl px-6 py-8">
                <header className="mb-8">
                    <div
                        className="mb-2 inline-flex rounded-full border px-3 py-1 text-sm"
                    >
                        Jac MCP Playground
                    </div>
                    <h1 className="text-3xl font-semibold tracking-tight">
                        Validate, format, and explain Jac code
                    </h1>
                    <p className="mt-2 max-w-3xl text-sm text-slate-600">
                        A focused internal tool for exercising Jac compiler workflows through backend walkers.
                    </p>
                </header>
                <div className="grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
                    <section className="rounded-2xl border bg-white p-4 shadow-sm">
                        <div className="mb-4 flex items-center justify-between gap-3">
                            <div>
                                <h2 className="text-lg font-medium">
                                    Editor
                                </h2>
                                <p className="text-sm text-slate-600">
                                    Keep the code sample small while the MCP integration is being proven.
                                </p>
                            </div>
                            <div className="flex flex-wrap gap-2">
                                <button
                                    className="rounded-xl border px-4 py-2 text-sm font-medium"
                                    disabled={loading}
                                    onClick={lambda -> None { run_validate();}}
                                >
                                    {loading
                                    and active_action == "validate"
                                    and "Validating..."}{(
                                        (not loading) or active_action != "validate"
                                    )
                                    and "Validate"}
                                </button>
                                <button
                                    className="rounded-xl border px-4 py-2 text-sm font-medium"
                                    disabled={loading}
                                    onClick={lambda -> None { run_format();}}
                                >
                                    {loading
                                    and active_action == "format"
                                    and "Formatting..."}{(
                                        (not loading) or active_action != "format"
                                    )
                                    and "Format"}
                                </button>
                                <button
                                    className="rounded-xl border px-4 py-2 text-sm font-medium"
                                    disabled={loading or explain_target.strip() == ""}
                                    onClick={lambda -> None { run_explain();}}
                                >
                                    {loading
                                    and active_action == "explain"
                                    and "Explaining..."}{(
                                        (not loading) or active_action != "explain"
                                    )
                                    and "Explain Error"}
                                </button>
                            </div>
                        </div>
                        <textarea
                            className="min-h-[460px] w-full rounded-2xl border p-4 font-mono text-sm outline-none"
                            value={code}
                            onChange={lambda e: any  -> None { code = e.target.value;}}
                            spellCheck={False}
                        />
                        <div className="mt-4 rounded-2xl border px-4 py-3">
                            <div
                                className="text-xs font-medium uppercase tracking-wide text-slate-500"
                            >
                                Status
                            </div>
                            <p className="mt-1 text-sm">
                                {notice}
                            </p>
                            {error_text != ""
                            and <p className="mt-2 text-sm text-red-600">
                                {error_text}
                            </p>}
                        </div>
                    </section>
                    <section className="space-y-6">
                        <div className="rounded-2xl border bg-white p-4 shadow-sm">
                            <div className="mb-3">
                                <h2 className="text-lg font-medium">
                                    Primary error
                                </h2>
                                <p className="text-sm text-slate-600">
                                    The first validation error is captured here for quick explanation.
                                </p>
                            </div>
                            <div className="rounded-2xl border p-4">
                                {explain_target != ""
                                and <pre className="whitespace-pre-wrap text-sm">
                                    {explain_target}
                                </pre>}{explain_target == ""
                                and <p className="text-sm text-slate-500">
                                    No compiler error selected yet.
                                </p>}
                            </div>
                        </div>
                        <div className="rounded-2xl border bg-white p-4 shadow-sm">
                            <div className="mb-3">
                                <h2 className="text-lg font-medium">
                                    Backend response
                                </h2>
                                <p className="text-sm text-slate-600">
                                    Raw normalized payload from your Jac backend.
                                </p>
                            </div>
                            <div className="rounded-2xl border bg-slate-50 p-4">
                                <pre
                                    className="overflow-x-auto whitespace-pre-wrap text-xs"
                                >
                                    {pretty_json(response)}
                                </pre>
                            </div>
                        </div>
                    </section>
                </div>
            </div>
        </div>;
}

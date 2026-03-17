import "../styles.css";

sv import from ..main {
    validate_code,
    format_code,
    explain_code_error,
    check_syntax,
    py_to_jac,
    list_examples,
    get_example,
    search_docs,
    get_ast
}


def get_first_report(spawn_result: any) -> dict {
    console.log("Raw spawn result:", spawn_result);

    if spawn_result == None {
        return {
            "ok": False,
            "tool": "unknown",
            "data": {},
            "error": {"message": "Spawn returned no result."}
        };
    }

    if spawn_result.reports {
        reports = spawn_result.reports;
        if len(reports) > 0 {
            return reports[0];
        }
    }

    if "reports" in spawn_result {
        reports = spawn_result["reports"];
        if reports and len(reports) > 0 {
            return reports[0];
        }
    }

    if "report" in spawn_result {
        return spawn_result["report"];
    }

    return {
        "ok": False,
        "tool": "unknown",
        "data": {"raw_spawn_result": spawn_result},
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

    if "errors" not in data {
        return "";
    }

    errors = data["errors"];

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

    if "formatted" in data {
        return data["formatted"];
    }

    return "";
}


def pretty_json(value: any) -> str {
    try {
        return JSON.stringify(value, null, 2);
    } except Exception {
        return "{}";
    }
}


def:pub Home() -> JsxElement {
    has code: str = "";

    has python_input: str = "";
    has python_output: str = "";

    has ast_output: str = "";

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
                notice = "Validation failed.";
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
        if code.strip() == "" {
            notice = "No code to format.";
            error_text = "Paste Jac code before formatting.";
            return;
        }

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
                notice = "Formatting completed, but no changes were returned.";
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
        target_error = explain_target.strip();

        if target_error == "" {
            target_error = code.strip();
        }

        if target_error == "" {
            error_text = "Provide an error message or run validation first.";
            return;
        }

        loading = True;
        active_action = "explain";
        error_text = "";
        notice = "Explaining compiler error...";

        try {
            spawn_result = await root spawn explain_code_error(
                error_message=target_error
            );

            payload = get_first_report(spawn_result);
            response = payload;

            notice = "Error explanation loaded.";
        } except Exception as e {
            response = {};
            error_text = f"Explain request failed: {e}";
        }

        loading = False;
    }

    async def run_check_syntax() -> None {
        loading = True;
        active_action = "check_syntax";
        error_text = "";
        notice = "Checking syntax...";

        try {
            spawn_result = await root spawn check_syntax(code=code);
            payload = get_first_report(spawn_result);
            response = payload;

            first_error = extract_first_validation_error(payload);
            explain_target = first_error;

            if "ok" in payload and payload["ok"] {
                if first_error == "" {
                    notice = "Syntax is valid.";
                } else {
                    notice = "Syntax check found issues.";
                }
            } else {
                notice = "Syntax check failed.";
                if "error" in payload and "message" in payload["error"] {
                    error_text = payload["error"]["message"];
                }
            }
        } except Exception as e {
            error_text = f"Syntax check failed: {e}";
            notice = "Syntax check request failed.";
        }

        loading = False;
    }

    async def run_get_ast() -> None {
        loading = True;
        notice = "Generating AST...";

        try {
            spawn_result = await root spawn get_ast(code=code, format="tree");
            payload = get_first_report(spawn_result);
            response = payload;

            if "data" in payload and "ast" in payload["data"] {
                ast_output = JSON.stringify(payload["data"]["ast"], null, 2);
            }

            notice = "AST generated.";
        } except Exception as e {
            error_text = f"AST generation failed: {e}";
            notice = "AST request failed.";
        }

        loading = False;
    }

    async def run_py_to_jac() -> None {
        loading = True;
        notice = "Translating Python to Jac...";

        try {
            spawn_result = await root spawn py_to_jac(python_code=python_input);
            payload = get_first_report(spawn_result);
            response = payload;

            if "data" in payload and "jac_code" in payload["data"] {
                python_output = payload["data"]["jac_code"];
            }

            notice = "Python converted to Jac.";
        } except Exception as e {
            error_text = f"Python conversion failed: {e}";
            notice = "Conversion failed.";
        }

        loading = False;
    }

    return
        <div className="min-h-screen bg-zinc-950 text-zinc-100">
            <div
                className="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,122,24,0.08),_transparent_35%)]"
            />
            <div className="relative mx-auto max-w-7xl px-6 py-6 space-y-5">
                <div className="flex items-center justify-between">
                    <h1 className="text-lg font-semibold tracking-tight text-white">
                        Jac MCP Playground
                    </h1>
                    <div className="text-[11px] text-zinc-500">
                        Validate · Format · Syntax · AST · Py → Jac
                    </div>
                </div>
                <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                    <div className="space-y-3">
                        <div
                            className="rounded-2xl border border-white/10 bg-zinc-900/90 shadow-[0_20px_60px_rgba(0,0,0,0.45)]"
                        >
                            <div
                                className="flex items-center justify-between border-b border-white/10 px-3 py-2"
                            >
                                <div className="flex items-center gap-2">
                                    <span className="h-2 w-2 rounded-full bg-red-400"/>
                                    <span
                                        className="h-2 w-2 rounded-full bg-yellow-400"
                                    />
                                    <span
                                        className="h-2 w-2 rounded-full bg-green-400"
                                    />
                                </div>
                                <div className="flex gap-2">
                                    <button
                                        className="px-2 py-1 text-[10px] rounded bg-orange-500 hover:bg-orange-400 text-white"
                                        disabled={loading}
                                        onClick={lambda -> None { run_validate();}}
                                    >
                                        Validate
                                    </button>
                                    <button
                                        className="px-2 py-1 text-[10px] rounded bg-white/5 hover:bg-white/10 border border-white/10"
                                        disabled={loading}
                                        onClick={lambda -> None { run_format();}}
                                    >
                                        Format
                                    </button>
                                    <button
                                        className="px-2 py-1 text-[10px] rounded bg-white/5 hover:bg-white/10 border border-white/10"
                                        disabled={loading}
                                        onClick={lambda -> None { run_check_syntax();}}
                                    >
                                        Syntax
                                    </button>
                                    <button
                                        className="px-2 py-1 text-[10px] rounded bg-white/5 hover:bg-white/10 border border-white/10"
                                        disabled={loading}
                                        onClick={lambda -> None { run_get_ast();}}
                                    >
                                        AST
                                    </button>
                                </div>
                            </div>
                            <textarea
                                className="w-full min-h-[520px] resize-none bg-[#0d0e10] p-4 font-mono text-xs leading-6 text-zinc-100 outline-none focus:ring-1 focus:ring-orange-400/40"
                                value={code}
                                onChange={lambda e: any  -> None { code = e.target.value;}}
                            />
                        </div>
                    </div>
                    <div className="space-y-4">
                        <div
                            className="rounded-xl border border-white/10 bg-zinc-900/80 p-3 space-y-2"
                        >
                            <div className="flex items-center justify-between">
                                <div
                                    className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    Response
                                </div>
                                <div className="text-xs text-zinc-400">
                                    {notice}
                                </div>
                            </div>
                            {error_text != ""
                            and <div
                                className="text-xs text-red-400 border border-red-500/20 bg-red-500/10 p-2 rounded"
                            >
                                {error_text}
                            </div>}
                            {(len(response) == 0)
                            and <div className="text-xs text-zinc-500">
                                No response yet.
                            </div>}
                            {(len(response) != 0)
                            and <pre
                                className="text-[11px] leading-6 text-zinc-300 max-h-[300px] overflow-auto bg-[#0d0e10] p-3 rounded border border-white/5 whitespace-pre-wrap break-words"
                            >
                                {pretty_json(response)}
                            </pre>}
                        </div>
                        <div
                            className="rounded-xl border border-white/10 bg-zinc-900/80 p-3"
                        >
                            <div
                                className="text-[11px] uppercase tracking-[0.18em] text-zinc-500 mb-2"
                            >
                                AST
                            </div>
                            {ast_output == ""
                            and <div className="text-xs text-zinc-500">
                                No AST generated yet.
                            </div>}
                            {ast_output != ""
                            and <pre
                                className="text-[11px] text-zinc-300 max-h-[220px] overflow-auto bg-[#0d0e10] p-3 rounded border border-white/5"
                            >
                                {ast_output}
                            </pre>}
                        </div>
                        <div
                            className="rounded-xl border border-white/10 bg-zinc-900/80 p-3 space-y-2"
                        >
                            <div className="flex items-center justify-between">
                                <div
                                    className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    Python → Jac
                                </div>
                                <button
                                    className="px-2 py-1 text-[10px] rounded bg-purple-600 hover:bg-purple-500 text-white"
                                    disabled={loading}
                                    onClick={lambda -> None { run_py_to_jac();}}
                                >
                                    Convert
                                </button>
                            </div>
                            <textarea
                                className="w-full min-h-[120px] bg-[#0d0e10] border border-white/10 rounded p-2 font-mono text-xs text-zinc-100 outline-none focus:ring-1 focus:ring-purple-400/40"
                                value={python_input}
                                onChange={lambda e: any  -> None { python_input = e.target.value;}}
                            />
                            {python_output == ""
                            and <div className="text-xs text-zinc-500">
                                No converted code yet.
                            </div>}
                            {python_output != ""
                            and <div className="space-y-2">
                                <button
                                    className="px-2 py-1 text-[10px] rounded bg-green-600 hover:bg-green-500 text-white"
                                    onClick={lambda -> None { navigator.clipboard.writeText(
                                        python_output
                                    );}}
                                >
                                    Copy
                                </button>
                                <pre
                                    className="text-[11px] text-green-400 max-h-[180px] overflow-auto bg-[#0d0e10] p-3 rounded border border-white/5"
                                >
                                    {python_output}
                                </pre>
                            </div>}
                        </div>
                    </div>
                </div>
            </div>
        </div>;
}

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
            console.log(spawn_result);
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
            spawn_result = await root spawn explain_code_error(
                error_message=target_error
            );
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
        <div className="min-h-screen bg-[#0b0b0d] text-zinc-100">
            <div
                className="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,122,24,0.12),_transparent_28%),linear-gradient(to_bottom,_rgba(255,255,255,0.02),_transparent_35%)]"
            />
            <div
                className="relative mx-auto max-w-7xl px-4 py-5 sm:px-6 sm:py-6 lg:px-8"
            >
                <header
                    className="mb-6 rounded-3xl border border-white/10 bg-[#111214]/90 shadow-[0_20px_80px_rgba(0,0,0,0.45)] backdrop-blur"
                >
                    <div
                        className="flex flex-col gap-4 px-5 py-5 sm:px-6 lg:flex-row lg:items-end lg:justify-between"
                    >
                        <div className="space-y-3">
                            <div
                                className="inline-flex items-center gap-2 rounded-full border border-orange-400/25 bg-orange-500/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-orange-300"
                            >
                                <span
                                    className="h-2 w-2 rounded-full bg-orange-400 shadow-[0_0_12px_rgba(251,146,60,0.9)]"
                                />
                                Jac MCP Playground
                            </div>
                            <div>
                                <h1
                                    className="text-2xl font-semibold tracking-tight text-white sm:text-3xl"
                                >
                                    Validate, format, and explain Jac code
                                </h1>
                                <p
                                    className="mt-2 max-w-3xl text-sm leading-6 text-zinc-400"
                                >
                                    A focused workspace for checking code quality, formatting snippets, and understanding errors faster.
                                </p>
                            </div>
                        </div>
                        <div className="grid grid-cols-2 gap-3 lg:min-w-[280px]">
                            <div
                                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
                            >
                                <div
                                    className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    Purpose
                                </div>
                                <div className="mt-1 text-sm font-medium text-zinc-100">
                                    Jac code workflow
                                </div>
                            </div>
                            <div
                                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
                            >
                                <div
                                    className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    Actions
                                </div>
                                <div className="mt-1 text-sm font-medium text-zinc-100">
                                    Validate · Format · Explain
                                </div>
                            </div>
                        </div>
                    </div>
                </header>
                <div className="mb-6 grid gap-3 sm:grid-cols-3">
                    <div
                        className="rounded-2xl border border-orange-400/20 bg-orange-500/10 px-4 py-3"
                    >
                        <div
                            className="text-[11px] uppercase tracking-[0.18em] text-orange-300"
                        >
                            1
                        </div>
                        <div className="mt-1 text-sm font-semibold text-white">
                            Paste or edit code
                        </div>
                    </div>
                    <div
                        className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
                    >
                        <div
                            className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                        >
                            2
                        </div>
                        <div className="mt-1 text-sm font-semibold text-white">
                            Run a code action
                        </div>
                    </div>
                    <div
                        className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
                    >
                        <div
                            className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                        >
                            3
                        </div>
                        <div className="mt-1 text-sm font-semibold text-white">
                            Review the output
                        </div>
                    </div>
                </div>
                <div className="grid gap-6 xl:grid-cols-[1.35fr_0.65fr]">
                    <section
                        className="rounded-3xl border border-white/10 bg-[#121316]/92 p-4 shadow-[0_20px_70px_rgba(0,0,0,0.35)] sm:p-5"
                    >
                        <div className="mb-4 flex flex-col gap-4">
                            <div
                                className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between"
                            >
                                <div>
                                    <h2 className="text-lg font-semibold text-white">
                                        Code
                                    </h2>
                                    <p className="mt-1 text-sm leading-6 text-zinc-400">
                                        Edit a Jac snippet, then run the action you need.
                                    </p>
                                </div>
                                <div
                                    className="inline-flex w-fit items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-medium text-zinc-400"
                                >
                                    Workspace
                                </div>
                            </div>
                            <div
                                className="flex flex-wrap gap-2 rounded-2xl border border-white/10 bg-[#0d0e10] p-2"
                            >
                                <button
                                    className="rounded-xl border border-orange-400/25 bg-orange-500 px-4 py-2 text-sm font-semibold text-white shadow-[0_10px_30px_rgba(249,115,22,0.25)] transition hover:bg-orange-400 disabled:cursor-not-allowed disabled:border-white/10 disabled:bg-white/5 disabled:text-zinc-500 disabled:shadow-none"
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
                                    className="rounded-xl border border-white/12 bg-white/5 px-4 py-2 text-sm font-semibold text-zinc-100 transition hover:border-orange-400/30 hover:bg-white/10 disabled:cursor-not-allowed disabled:border-white/8 disabled:bg-white/5 disabled:text-zinc-500"
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
                                    className="rounded-xl border border-white/12 bg-white/5 px-4 py-2 text-sm font-semibold text-zinc-100 transition hover:border-orange-400/30 hover:bg-white/10 disabled:cursor-not-allowed disabled:border-white/8 disabled:bg-white/5 disabled:text-zinc-500"
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
                        <div
                            className="overflow-hidden rounded-2xl border border-white/10 bg-[#0d0e10] shadow-inner"
                        >
                            <div
                                className="flex items-center justify-between border-b border-white/8 px-4 py-3"
                            >
                                <div className="flex items-center gap-2">
                                    <span
                                        className="h-2.5 w-2.5 rounded-full bg-red-400/80"
                                    />
                                    <span
                                        className="h-2.5 w-2.5 rounded-full bg-yellow-400/80"
                                    />
                                    <span
                                        className="h-2.5 w-2.5 rounded-full bg-green-400/80"
                                    />
                                </div>
                                <div
                                    className="text-xs font-medium uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    editor
                                </div>
                            </div>
                            <textarea
                                className="min-h-[540px] w-full resize-none bg-transparent p-4 font-mono text-sm leading-7 text-zinc-100 outline-none placeholder:text-zinc-500"
                                value={code}
                                onChange={lambda e: any  -> None { code = e.target.value;}}
                                spellCheck={False}
                            />
                        </div>
                        <div
                            className="mt-4 rounded-2xl border border-white/10 bg-white/5 px-4 py-4"
                        >
                            <div className="flex items-center justify-between gap-3">
                                <div
                                    className="text-xs font-semibold uppercase tracking-[0.18em] text-zinc-500"
                                >
                                    Status
                                </div>
                                <div className="text-xs text-zinc-400">
                                    {loading and "Processing..."}{(not loading)
                                    and "Idle"}
                                </div>
                            </div>
                            <p className="mt-2 text-sm leading-6 text-zinc-200">
                                {notice}
                            </p>
                            {error_text != ""
                            and <div
                                className="mt-3 rounded-xl border border-red-400/20 bg-red-500/10 px-3 py-3"
                            >
                                <p className="text-sm leading-6 text-red-200">
                                    {error_text}
                                </p>
                            </div>}
                        </div>
                    </section>
                    <aside className="space-y-6">
                        <div
                            className="rounded-3xl border border-white/10 bg-[#121316]/92 p-5 shadow-[0_20px_70px_rgba(0,0,0,0.35)]"
                        >
                            <div
                                className="mb-4 flex items-center justify-between gap-3"
                            >
                                <div>
                                    <div
                                        className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                    >
                                        Issue
                                    </div>
                                    <h2
                                        className="mt-1 text-lg font-semibold text-white"
                                    >
                                        Primary error
                                    </h2>
                                </div>
                                <div
                                    className="rounded-full border border-orange-400/20 bg-orange-500/10 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-orange-300"
                                >
                                    selected
                                </div>
                            </div>
                            <div
                                className="rounded-2xl border border-white/10 bg-[#0d0e10] p-4"
                            >
                                {explain_target != ""
                                and <pre
                                    className="whitespace-pre-wrap font-mono text-sm leading-6 text-zinc-200"
                                >
                                    {explain_target}
                                </pre>}{explain_target == ""
                                and <div
                                    className="rounded-xl border border-dashed border-white/10 bg-white/[0.03] px-4 py-6 text-sm text-zinc-500"
                                >
                                    Run validation to populate the first error here.
                                </div>}
                            </div>
                        </div>
                        <div
                            className="rounded-3xl border border-white/10 bg-[#121316]/92 p-5 shadow-[0_20px_70px_rgba(0,0,0,0.35)]"
                        >
                            <div
                                className="mb-4 flex items-center justify-between gap-3"
                            >
                                <div>
                                    <div
                                        className="text-[11px] uppercase tracking-[0.18em] text-zinc-500"
                                    >
                                        Result
                                    </div>
                                    <h2
                                        className="mt-1 text-lg font-semibold text-white"
                                    >
                                        Output
                                    </h2>
                                </div>
                                <div
                                    className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-zinc-400"
                                >
                                    json
                                </div>
                            </div>
                            <div
                                className="rounded-2xl border border-white/10 bg-[#0d0e10] p-4"
                            >
                                <pre
                                    className="max-h-[420px] overflow-x-auto overflow-y-auto whitespace-pre-wrap font-mono text-xs leading-6 text-zinc-300"
                                >
                                    {pretty_json(response)}
                                </pre>
                            </div>
                        </div>
                    </aside>
                </div>
            </div>
        </div>;
}

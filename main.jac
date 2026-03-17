import from backend.service {
    validate_code_service,
    format_code_service,
    explain_code_error_service,
    check_syntax_service,
    py_to_jac_service,
    list_examples_service,
    get_example_service,
    search_docs_service,
    get_ast_service
}

import from backend.utils {
    empty_code_response,
    empty_error_message_response,
    empty_python_code_response,
    empty_query_response
}

walker:pub validate_code {
    has code: str;
    has output: dict = {};

    can handle with Root entry {
        if self.code.strip() == "" {
            self.output = empty_code_response("validate_jac");
            report self.output;
            disengage;
        }

        self.output = validate_code_service(self.code);
        report self.output;
    }
}

walker:pub format_code {
    has code: str;
    has output: dict = {};

    can handle with Root entry {
        if self.code.strip() == "" {
            self.output = empty_code_response("format_jac");
            report self.output;
            disengage;
        }

        self.output = format_code_service(self.code);
        report self.output;
    }
}

walker:pub explain_code_error {
    has error_message: str;
    has output: dict = {};

    can handle with Root entry {
        if self.error_message.strip() == "" {
            self.output = empty_error_message_response();
            report self.output;
            disengage;
        }

        self.output = explain_code_error_service(self.error_message);
        report self.output;
    }
}

walker:pub check_syntax {
    has code: str;
    has output: dict = {};

    can handle with Root entry {
        if self.code.strip() == "" {
            self.output = empty_code_response("check_syntax");
            report self.output;
            disengage;
        }

        self.output = check_syntax_service(self.code);
        report self.output;
    }
}

walker:pub py_to_jac {
    has python_code: str;
    has output: dict = {};

    can handle with Root entry {
        if self.python_code.strip() == "" {
            self.output = empty_python_code_response();
            report self.output;
            disengage;
        }

        self.output = py_to_jac_service(self.python_code);
        report self.output;
    }
}

walker:pub list_examples {
    has category: str = "";
    has output: dict = {};

    can handle with Root entry {
        cat: str | None = None;
        if self.category.strip() != "" {
            cat = self.category;
        }

        self.output = list_examples_service(cat);
        report self.output;
    }
}

walker:pub get_example {
    has name: str;
    has output: dict = {};

    can handle with Root entry {
        if self.name.strip() == "" {
            self.output = empty_code_response("get_example");
            report self.output;
            disengage;
        }

        self.output = get_example_service(self.name);
        report self.output;
    }
}

walker:pub search_docs {
    has query: str;
    has limit: int = 10;
    has output: dict = {};

    can handle with Root entry {
        if self.query.strip() == "" {
            self.output = empty_query_response();
            report self.output;
            disengage;
        }

        self.output = search_docs_service(self.query, self.limit);
        report self.output;
    }
}

walker:pub get_ast {
    has code: str;
    has format: str = "tree";
    has output: dict = {};

    can handle with Root entry {
        if self.code.strip() == "" {
            self.output = empty_code_response("get_ast");
            report self.output;
            disengage;
        }

        self.output = get_ast_service(self.code, self.format);
        report self.output;
    }
}


cl import from ".frontend.home" { Home }

cl {
    def:pub app() -> JsxElement {
        return
            <Home/>;
    }
}

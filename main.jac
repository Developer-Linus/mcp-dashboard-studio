import from backend.service {
    validate_code_service,
    format_code_service,
    explain_code_error_service
}

import from backend.utils { empty_code_response, empty_error_message_response }

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


cl import from ".frontend.home" { Home }

cl {
    def:pub app() -> JsxElement {
        return
            <Home/>;
    }
}

include backend.api;

cl import from ".frontend.home" { Home }

cl {
    def:pub app() -> JsxElement {
        return
            <Home/>;
    }
}

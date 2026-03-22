# Jac testing reference

### Instructions for an AI coding agent

---

## What testing is in Jac

Jac has testing built into the language. You do **not** import a test framework. You do **not** follow file naming conventions to trigger test discovery. You write `test "description" { ... }` blocks directly in `.jac` files. These blocks are ignored by `jac run` and only execute under `jac test`.

---

## 1 — Test block anatomy

**Exact syntax:** `test "description string" { body; }` — the keyword is `test`, followed by a quoted string, then a block. No function name. No decorator. No class.

```jac
test "calculator adds two positive numbers" {
    calc = Calculator();
    result = calc.add(2, 3);
    assert result == 5, f"Expected 5, got {result}";
}
```

- Use `assert` for every check — no `assertEqual`, no `assertTrue`, no external matchers.
- Always include an error message on non-obvious assertions: `assert x == y, f"Expected {y}, got {x}"`.
- One logical behaviour per test block. Do not test multiple unrelated things in one block.

---

## 2 — Isolation rules ⚠️ CRITICAL

Every `test` block gets a completely fresh graph. Nodes attached to `root` in test A do not exist in test B. There is no shared state. You do not need setup/teardown. You do not need to clean up after a test.

> **NodeAnchor errors on re-run?** This means stale persisted state from a previous `jac run` is interfering. Fix: run `jac clean --all` before retrying. The in-memory graph resets per test block, but on-disk local storage does not reset automatically.

```jac
# CORRECT — both tests create their own fresh Counter node
test "counter starts at zero" {
    counter = Counter();
    assert counter.count == 0;
}

test "counter increments" {
    counter = root ++> Counter();
    root spawn Incrementer();
    assert counter[0].count == 1;
}
# The second test's node does NOT persist into the first, regardless of run order.
```

---

## 3 — All assertion forms

```jac
# Equality / identity
assert a == b;
assert a != b;
assert a is b;          # same object in memory
assert a is not b;

# Ordered comparisons
assert a > b;
assert a >= b;
assert a < b;
assert a <= b;

# Boolean
assert True;
assert not False;
assert bool(value);

# Membership
assert item in collection;
assert item not in collection;
assert key in dictionary;

# Type checks
assert isinstance(obj, MyClass);
assert type(obj) == MyClass;

# None checks
assert value is None;
assert value is not None;

# Float comparison — use almostEqual, never ==
result = 0.1 + 0.2;
assert almostEqual(result, 0.3, 10);

# With message (always prefer this form)
assert result > 0, f"Expected positive, got {result}";
assert len(items) == 3, "Should have exactly 3 items";
```

---

## 4 — Testing walkers and graphs

**Walker mutates node state:**

```jac
test "walker mutates node" {
    c = root ++> Counter();
    root spawn Incrementer(amount=5);
    assert c[0].count == 5;
}
```

**Walker reports:**

```jac
test "reports only adults" {
    root ++> Person(name="Alice", age=30);
    root ++> Person(name="Bob", age=15);
    r = root spawn FindAdults();
    assert len(r.reports) == 1;
    assert r.reports[0].name == "Alice";
}
```

**Graph edges:**

```jac
test "door connects rooms" {
    a = Room(name="A");
    b = Room(name="B");
    root ++> a;
    a +>: Door() :+> b;
    assert b in [a ->:Door:->];
    assert len([a -->]) == 1;
}
```

**Leaf node has no children:**

```jac
test "leaf has no outgoing edges" {
    leaf = root ++> Room(name="Leaf");
    assert len([leaf[0] -->]) == 0;
}
```

---

## 5 — Testing exceptions ⚠️ EXACT PATTERN REQUIRED

You **MUST** write `assert False, "Should have raised ..."` on the line immediately after the call that is expected to throw. Without it, a no-throw silently passes the test.

```jac
test "divide by zero raises ZeroDivisionError" {
    try {
        divide(10, 0);
        assert False, "Should have raised ZeroDivisionError";  # ← mandatory
    } except ZeroDivisionError {
        assert True;  # expected path reached
    }
}
```

---

## 6 — CLI commands

| Command                           | Flag | What it does                      |
| --------------------------------- | ---- | --------------------------------- |
| `jac test main.jac`               |      | Run all tests in a file           |
| `jac test -d tests/`              | `-d` | Run all tests in a directory      |
| `jac test main.jac -t my_feature` | `-t` | Run one test by exact name        |
| `jac test main.jac -f "user_"`    | `-f` | Run tests matching a pattern      |
| `jac test main.jac -x`            | `-x` | Stop immediately on first failure |
| `jac test -d tests/ -m 3`         | `-m` | Stop after N total failures       |
| `jac test main.jac -v`            | `-v` | Verbose output                    |
| `jac clean --all`                 |      | Clear stale persisted graph state |

---

## 7 — File naming ⚠️ GOTCHA

**Never** name a `.jac` test file with a `test_` prefix (e.g. `test_utils.jac`). This conflicts with Python's module import system and will cause import errors. Use a suffix instead:

- `utils_tests.jac` ✓
- `models_test.jac` ✓
- `test_utils.jac` ✗

---

## 8 — Parametrized tests

Use `parametrize()` to run one test function against a list of inputs. Each input becomes a separately named test case. Must be called inside a `with entry { }` block — **not** inside a `test` block.

```jac
import from jaclang.runtimelib.test { parametrize }

def _test_square(pair: tuple) {
    result = pair[0] ** 2;
    assert result == pair[1], f"Expected {pair[1]}, got {result}";
}

with entry {
    parametrize(
        "square",                            # base name
        [(2, 4), (3, 9), (0, 0), (-1, 1)],  # params list
        _test_square                          # function to call per param
    );
}
# Registers: square_0, square_1, square_2, square_3
```

**Optional: custom IDs via `id_fn`:**

```jac
parametrize(
    "parse",
    ["500m", "2", "250"],
    _test_parse,
    id_fn=lambda p: str -> str { return f"input_{p}"; }
);
# Registers: parse_input_500m, parse_input_2, parse_input_250
```

**`parametrize()` signature:**

| Parameter   | Type               | Description                                                     |
| ----------- | ------------------ | --------------------------------------------------------------- |
| `base_name` | `str`              | Base name for the generated tests                               |
| `params`    | `Iterable`         | List of parameter values passed one-by-one to the test function |
| `test_func` | `Callable`         | Function to invoke with each parameter                          |
| `id_fn`     | `Callable \| None` | Optional function to generate descriptive test IDs              |

---

## 9 — HTTP endpoint testing (JacTestClient)

`JacTestClient` is an in-process HTTP client. It does **not** start a real server and does **not** open any network port. Import it from Python, not from a `.jac` file.

```python
from jaclang.runtimelib.testing import JacTestClient

def test_crud(tmp_path):
    client = JacTestClient.from_file("app.jac", base_path=str(tmp_path))
    client.register_user("alice", "pass123")    # registers and logs in

    r = client.post("/walker/CreateTask", json={"title": "Buy milk"})
    assert r.status_code == 200
    assert r.ok                                 # True for any 2xx

    r = client.post("/walker/GetTasks")
    assert len(r.json()["reports"]) == 1

    client.close()                              # always close
```

**Available request methods:**

| Method                                  | Usage                       |
| --------------------------------------- | --------------------------- |
| `client.get(path)`                      | GET request                 |
| `client.post(path, json={})`            | POST request with JSON body |
| `client.put(path, json={})`             | PUT request with JSON body  |
| `client.request(method, path, json={})` | Any HTTP method             |
| `client.get(path, headers={})`          | With custom headers         |

**`TestResponse` properties:**

| Property      | Type           | Description                                       |
| ------------- | -------------- | ------------------------------------------------- |
| `status_code` | `int`          | HTTP status code                                  |
| `ok`          | `bool`         | `True` if status is 2xx                           |
| `text`        | `str`          | Raw response body                                 |
| `json()`      | `dict`         | Parse body as JSON                                |
| `data`        | `dict \| None` | Unwrapped payload from TransportResponse envelope |

**Authentication helpers:**

```python
client.register_user("user", "pass")   # register + auto-login
client.login("user", "pass")           # login only
client.set_auth_token("eyJ...")        # set token manually
client.clear_auth()                    # clear token
client.reload()                        # simulate file change (HMR testing)
```

---

## 10 — Project layout

```
myproject/
├── jac.toml
├── src/
│   ├── models.jac
│   └── walkers.jac
└── tests/
    ├── models_test.jac    # NOT test_models.jac
    └── walkers_test.jac
```

Tests can also live at the bottom of the same `.jac` file as the code they test. Either approach works — `test` blocks are always skipped by `jac run`.

**`jac.toml` test configuration (optional):**

```toml
[test]
directory = "tests"
verbose = true
fail_fast = false
max_failures = 10
```

---

## 11 — Rules the agent must never break

1. Use `test "description" { }` syntax only — no pytest-style function names, no test class, no framework imports.
2. Use only `assert` for all checks — no `assertEqual`, no third-party matchers.
3. Always pair float comparisons with `almostEqual`, never `==`.
4. Never rely on state from another test block. All fixtures (nodes, objects) must be created inside the block.
5. In exception tests, always write `assert False, "Should have raised ..."` on the line immediately after the throwing call.
6. Always include a descriptive message string in non-obvious `assert` calls.
7. Never name test files with a `test_` prefix.
8. Run `jac clean --all` if `NodeAnchor` errors appear on re-run.
9. Call `client.close()` after every `JacTestClient` session.
10. Call `parametrize()` inside `with entry { }`, never inside a `test` block.

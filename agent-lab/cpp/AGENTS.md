# C++14 and Google Style Rules

These rules apply to every file under `agent-lab/cpp` and override the parent C++17 declaration for this subproject.

## Language

- All production and test code MUST compile as ISO C++14 with extensions disabled.
- NEVER use C++17 or newer features, including structured bindings, `if constexpr`, inline variables, class template argument deduction, nested namespace syntax, `std::optional`, `std::variant`, `std::any`, `std::string_view`, or `std::filesystem`.
- Prefer existing C++14-compatible project patterns; do not add compatibility shims unless requested.

## Style

- Follow the Google C++ Style Guide and this directory's `.clang-format`.
- Types and functions use `PascalCase`; variables and parameters use `snake_case`; constants use `kPascalCase`; private data members use a trailing underscore.
- Namespaces use lowercase names; macros use `UPPER_SNAKE_CASE`.
- Use self-contained headers with project-style header guards.
- Prefer RAII and value semantics. Raw pointers are non-owning; do not call `new` or `delete` directly.
- Do not reformat or rename unrelated existing code.

## Verification

Before completion, run:

```sh
cmake -S agent-lab/cpp -B agent-lab/cpp/build
cmake --build agent-lab/cpp/build
ctest --test-dir agent-lab/cpp/build --output-on-failure
agent-lab/cpp/build/expense-report agent-lab/cpp/sample.txt
agent-lab/cpp/build/expense-report --category food agent-lab/cpp/sample.txt
```

Format changed C++ files with `clang-format` when available. Never claim a check passed unless it was actually run.

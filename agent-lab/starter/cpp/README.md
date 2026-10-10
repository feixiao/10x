# Expense report agent lab

Reads whitespace-separated `CATEGORY AMOUNT` rows and prints row count and total. Malformed rows are ignored.

Build and run:

```sh
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
./build/expense-report sample.txt
```

Agent task: add `--category CATEGORY`. Match category case-insensitively; without the option include every valid row. Keep malformed-row handling and output format unchanged. `sample.txt` contains:

```text
food 12.50
travel 20.00
FOOD 7.50
broken
```

Expected unfiltered output: `count=3 total=40.00`; expected `--category food` output: `count=2 total=20.00`.

Ask the agent to inspect the project and existing tests first, implement only this behavior, add coverage, run the listed checks plus a CLI check, and report actual commands, results, and diff. Record total elapsed time including review and repair.

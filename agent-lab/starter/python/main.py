import sys
from pathlib import Path


def summarize(lines):
    count = 0
    total = 0.0
    for line in lines:
        fields = line.split()
        if len(fields) != 2:
            continue
        try:
            amount = float(fields[1])
        except ValueError:
            continue
        count += 1
        total += amount
    return count, total


def main(argv):
    if len(argv) != 1:
        print("usage: expense-report FILE", file=sys.stderr)
        return 2
    try:
        with Path(argv[0]).open(encoding="utf-8") as input_file:
            count, total = summarize(input_file)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    print(f"count={count} total={total:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

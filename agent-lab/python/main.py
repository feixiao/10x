import sys
from pathlib import Path

ASCII_LOWER = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")


def summarize(lines, category=None):
    count = 0
    total = 0.0
    for line in lines:
        fields = line.split()
        if len(fields) != 2:
            continue
        if category is not None and fields[0].translate(ASCII_LOWER) != category.translate(ASCII_LOWER):
            continue
        try:
            amount = float(fields[1])
        except ValueError:
            continue
        count += 1
        total += amount
    return count, total


def main(argv):
    category = None
    if len(argv) == 1:
        file_name = argv[0]
    elif len(argv) == 3 and argv[0] == "--category":
        category, file_name = argv[1:]
    else:
        print("usage: expense-report [--category CATEGORY] FILE", file=sys.stderr)
        return 2
    try:
        with Path(file_name).open(encoding="utf-8") as input_file:
            count, total = summarize(input_file, category)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    print(f"count={count} total={total:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

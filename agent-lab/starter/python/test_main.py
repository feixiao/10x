import unittest

from main import summarize


class SummaryTests(unittest.TestCase):
    def test_counts_valid_rows_and_ignores_malformed_rows(self):
        count, total = summarize(
            ["food 12.50\n", "travel 20.00\n", "FOOD 7.50\n", "broken\n"]
        )
        self.assertEqual(count, 3)
        self.assertEqual(total, 40.0)


if __name__ == "__main__":
    unittest.main()

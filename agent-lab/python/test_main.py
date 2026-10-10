import unittest

from main import summarize


class SummaryTests(unittest.TestCase):
    def test_counts_valid_rows_and_ignores_malformed_rows(self):
        count, total = summarize(
            ["food 12.50\n", "travel 20.00\n", "FOOD 7.50\n", "broken\n"]
        )
        self.assertEqual(count, 3)
        self.assertEqual(total, 40.0)

    def test_filters_food_category(self):
        count, total = summarize(
            ["food 12.50\n", "travel 20.00\n", "FOOD 7.50\n", "broken\n"],
            "food",
        )
        self.assertEqual((count, total), (2, 20.0))

    def test_category_filter_is_ascii_case_insensitive(self):
        count, total = summarize(
            ["food 12.50\n", "travel 20.00\n", "FOOD 7.50\n", "broken\n"],
            "TRAVEL",
        )
        self.assertEqual((count, total), (1, 20.0))

    def test_unknown_category_has_empty_summary(self):
        count, total = summarize(["food 12.50\n", "travel 20.00\n"], "other")
        self.assertEqual((count, total), (0, 0.0))


if __name__ == "__main__":
    unittest.main()

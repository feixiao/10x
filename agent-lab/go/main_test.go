package main

import (
	"strings"
	"testing"
)

func TestSummarize(t *testing.T) {
	input := "food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n"
	tests := []struct {
		name     string
		category string
		count    int
		total    float64
	}{
		{name: "unfiltered", count: 3, total: 40},
		{name: "food", category: "food", count: 2, total: 20},
		{name: "case insensitive travel", category: "TRAVEL", count: 1, total: 20},
		{name: "unknown category", category: "transport", count: 0, total: 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := summarizeCategory(strings.NewReader(input), tt.category)
			if err != nil {
				t.Fatal(err)
			}
			if result.Count != tt.count || result.Total != tt.total {
				t.Fatalf("got %+v, want count=%d total=%.2f", result, tt.count, tt.total)
			}
		})
	}
}

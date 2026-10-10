package main

import (
	"strings"
	"testing"
)

func TestSummarize(t *testing.T) {
	result, err := summarize(strings.NewReader("food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n"))
	if err != nil {
		t.Fatal(err)
	}
	if result.Count != 3 || result.Total != 40 {
		t.Fatalf("got %+v, want count=3 total=40", result)
	}
}

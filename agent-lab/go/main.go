package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

type Summary struct {
	Count int
	Total float64
}

func summarize(input io.Reader) (Summary, error) {
	return summarizeCategory(input, "")
}

func summarizeCategory(input io.Reader, category string) (Summary, error) {
	var result Summary
	scanner := bufio.NewScanner(input)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) != 2 {
			continue
		}
		amount, err := strconv.ParseFloat(fields[1], 64)
		if err != nil {
			continue
		}
		if category != "" && !asciiEqualFold(fields[0], category) {
			continue
		}
		result.Count++
		result.Total += amount
	}
	return result, scanner.Err()
}

func asciiEqualFold(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		ac, bc := a[i], b[i]
		if ac >= 'A' && ac <= 'Z' {
			ac += 'a' - 'A'
		}
		if bc >= 'A' && bc <= 'Z' {
			bc += 'a' - 'A'
		}
		if ac != bc {
			return false
		}
	}
	return true
}

func main() {
	var category, filename string
	args := os.Args[1:]
	if len(args) == 3 && args[0] == "--category" {
		category, filename = args[1], args[2]
	} else if len(args) == 1 {
		filename = args[0]
	} else {
		fmt.Fprintln(os.Stderr, "usage: expense-report [--category CATEGORY] FILE")
		os.Exit(2)
	}
	input, err := os.Open(filename)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer input.Close()
	result, err := summarizeCategory(input, category)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("count=%d total=%.2f\n", result.Count, result.Total)
}

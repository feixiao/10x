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
		result.Count++
		result.Total += amount
	}
	return result, scanner.Err()
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: expense-report FILE")
		os.Exit(2)
	}
	input, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer input.Close()
	result, err := summarize(input)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("count=%d total=%.2f\n", result.Count, result.Total)
}

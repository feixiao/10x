#include "expense.h"

#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "usage: expense-report FILE\n";
        return 2;
    }
    std::ifstream input(argv[1]);
    if (!input) {
        std::cerr << "cannot open input file: " << argv[1] << '\n';
        return 1;
    }
    const auto result = summarize(input);
    std::cout << "count=" << result.count << " total=" << std::fixed
              << std::setprecision(2) << result.total << '\n';
}

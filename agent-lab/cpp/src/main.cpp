#include "expense.h"

#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    std::string category;
    const char* filename;
    if (argc == 2) {
        filename = argv[1];
    } else if (argc == 4 && std::string(argv[1]) == "--category") {
        category = argv[2];
        filename = argv[3];
    } else {
        std::cerr << "usage: expense-report [--category CATEGORY] FILE\n";
        return 2;
    }
    std::ifstream input(filename);
    if (!input) {
        std::cerr << "cannot open input file: " << filename << '\n';
        return 1;
    }
    const auto result = summarize(input, category);
    std::cout << "count=" << result.count << " total=" << std::fixed
              << std::setprecision(2) << result.total << '\n';
}

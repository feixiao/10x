#include "expense.h"

#include <cassert>
#include <cmath>
#include <sstream>
#include <string>

int main() {
    std::istringstream input("food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n");
    const auto result = summarize(input);
    assert(result.count == 3);
    assert(std::abs(result.total - 40.0) < 1e-9);
}

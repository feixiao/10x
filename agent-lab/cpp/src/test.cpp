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

    std::istringstream food_input("food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n");
    const auto food = summarize(food_input, "food");
    assert(food.count == 2);
    assert(std::abs(food.total - 20.0) < 1e-9);

    std::istringstream travel_input("food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n");
    const auto travel = summarize(travel_input, "TRAVEL");
    assert(travel.count == 1);
    assert(std::abs(travel.total - 20.0) < 1e-9);

    std::istringstream unknown_input("food 12.50\ntravel 20.00\nFOOD 7.50\nbroken\n");
    const auto unknown = summarize(unknown_input, "unknown");
    assert(unknown.count == 0);
    assert(std::abs(unknown.total) < 1e-9);
}

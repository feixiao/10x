#include "expense.h"

#include <sstream>
#include <string>

Summary summarize(std::istream& input) {
    Summary result;
    std::string line;
    while (std::getline(input, line)) {
        std::istringstream row(line);
        std::string category;
        double amount;
        if (row >> category >> amount) {
            ++result.count;
            result.total += amount;
        }
    }
    return result;
}

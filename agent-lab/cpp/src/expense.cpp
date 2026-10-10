#include "expense.h"

#include <sstream>
#include <string>

namespace {
bool ascii_case_equal(const std::string& left, const std::string& right) {
    if (left.size() != right.size()) return false;
    for (std::size_t i = 0; i < left.size(); ++i) {
        auto a = static_cast<unsigned char>(left[i]);
        auto b = static_cast<unsigned char>(right[i]);
        if (a >= 'A' && a <= 'Z') a += 'a' - 'A';
        if (b >= 'A' && b <= 'Z') b += 'a' - 'A';
        if (a != b) return false;
    }
    return true;
}
}

Summary summarize(std::istream& input, const std::string& category_filter) {
    Summary result;
    std::string line;
    while (std::getline(input, line)) {
        std::istringstream row(line);
        std::string category;
        double amount;
        if (row >> category >> amount) {
            if (!category_filter.empty() && !ascii_case_equal(category, category_filter)) continue;
            ++result.count;
            result.total += amount;
        }
    }
    return result;
}

#pragma once

#include <istream>
#include <string>

struct Summary {
    int count = 0;
    double total = 0.0;
};

Summary summarize(std::istream& input, const std::string& category_filter = "");

#pragma once

#include <istream>

struct Summary {
    int count = 0;
    double total = 0.0;
};

Summary summarize(std::istream& input);

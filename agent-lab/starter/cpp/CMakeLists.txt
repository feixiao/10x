cmake_minimum_required(VERSION 3.20)
project(expense_report LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(expense-report src/main.cpp src/expense.cpp)
enable_testing()
add_executable(expense-report-test src/test.cpp src/expense.cpp)
add_test(NAME expense-report-test COMMAND expense-report-test)

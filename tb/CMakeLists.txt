cmake_minimum_required(VERSION 3.15)
project(axis_pack_simulation LANGUAGES NONE)

# Check for Verilator version
find_program(VERILATOR_BIN verilator REQUIRED)

if(NOT VERILATOR_BIN)
    message(FATAL_ERROR "Verilator not found. Please install it and ensure it is in your PATH.")
endif()

execute_process(
    COMMAND ${VERILATOR_BIN} --version
    OUTPUT_VARIABLE VERILATOR_VERSION_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

string(REGEX REPLACE "Verilator ([0-9]+\\.[0-9]+) .*" "\\1" VERILATOR_VERSION ${VERILATOR_VERSION_OUTPUT})

if(VERILATOR_VERSION VERSION_LESS "5.022")
    message(FATAL_ERROR "Verilator version 5.022 or later is required, but found version ${VERILATOR_VERSION}.")
endif()

# Find Python 3
find_package(Python3 REQUIRED COMPONENTS Interpreter)

if(NOT Python3_Interpreter_FOUND)
    message(FATAL_ERROR "Python 3 interpreter not found. Please ensure Python 3 is installed and available in your PATH.")
endif()

set(PYTHON_EXECUTABLE ${Python3_EXECUTABLE})

# Check for Cocotb
execute_process(
    COMMAND python3 -c "import cocotb; print(cocotb.__version__)"
    RESULT_VARIABLE COCOTB_FOUND
    OUTPUT_VARIABLE COCOTB_VERSION_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

if(NOT COCOTB_FOUND EQUAL 0)
    message(FATAL_ERROR "Cocotb not found. Please install it using 'pip3 install cocotb~=1.9.2'.")
endif()

# Check Cocotb version
set(REQUIRED_COCOTB_VERSION "1.9.2")
if(NOT COCOTB_VERSION_OUTPUT STREQUAL REQUIRED_COCOTB_VERSION)
    message(FATAL_ERROR "Cocotb version ${REQUIRED_COCOTB_VERSION} is required, but found version ${COCOTB_VERSION_OUTPUT}.")
endif()

# Check for cocotbext-axi
execute_process(
    COMMAND python3 -c "import cocotbext.axi"
    RESULT_VARIABLE COCOTBEXT_AXI_FOUND
    ERROR_QUIET
)

if (NOT COCOTBEXT_AXI_FOUND EQUAL 0)
    message(FATAL_ERROR "cocotbext-axi not found. Please install it using 'pip3 install cocotbext-axi'.")
endif()


# Enable testing and include CTest
enable_testing()
include(CTest)

# Link the RTL directory to the build directory
file(COPY ${CMAKE_SOURCE_DIR}/../ip/rtl DESTINATION ${CMAKE_BINARY_DIR}/)
file(COPY ${CMAKE_SOURCE_DIR}/run_test.py DESTINATION ${CMAKE_BINARY_DIR}/tb)

add_test(NAME axis_pack_tests
    COMMAND ${PYTHON_EXECUTABLE} -m pytest ${CMAKE_BINARY_DIR}/tb
)
# Set the test timeout to 7200 seconds (2 hours) because we have some long-running tests
set_tests_properties(axis_pack_tests PROPERTIES TIMEOUT 7200)
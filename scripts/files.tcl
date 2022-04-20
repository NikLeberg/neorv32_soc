# Gather all available vhdl source files. (This assumes the vhdl entities are
# organized in subfolders and have their testbenches in a tb subfolders.)
set files [glob ../vhdl/*.vhdl ../vhdl/**/*.vhdl ../vhdl/**/tb/*.vhdl]

# List the entities in the order that they should be compiled. (This assumes
# entity file and entity itself have the same name.)
set entities {
    "example"
    
    "geni"
}

# List the testbenches in the order that they should be compiled and executed.
# (This assumes testbench file and entity have the same name.)
set testbenches {
    "example_tb"
}

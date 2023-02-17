# Gather all available vhdl source files. (This assumes the vhdl entities are
# organized in subfolders and have their testbenches in a tb subfolders.)
set files [glob                                                                \
    ../vhdl/*.vhd*                                                             \
    ../vhdl/**/*.vhd* ../vhdl/**/tb/*.vhd*                                     \
    ../vhdl/**/**/*.vhd* ../vhdl/**/**/tb/*.vhd*                               \
]

# List the entities in the order that they should be compiled. For example if
# you put "counter" a file named "counter.vhd{l}" is searched for.
set entities {
    "sdram_controller"

    "top"
}

# List the testbenches in the order that they should be compiled and executed.
# (This assumes testbench file and entity have the same name.)
set testbenches {
    "top_tb"
}

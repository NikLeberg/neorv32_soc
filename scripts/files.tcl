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
    "sdram"

    "wb_pkg"
    "wb_mux"
    "wb_crossbar"
    "wb_sdram"
    "wb_imem"
    "wb_dmem"

    "neorv32_wb_gateway"
    "neorv32_cpu_smp"
    "neorv32_wb_gpio"

    "gcd"
    "wb_gcd"

    "top"
}

# List the testbenches in the order that they should be compiled and executed.
# (This assumes testbench file and entity have the same name.)
set testbenches {
    "gcd_tb"

    "wb_crossbar_tb"
    "wb_gcd_tb"

    "top_tb"
}

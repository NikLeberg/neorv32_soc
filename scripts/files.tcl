# Gather all available vhdl source files. (This assumes the vhdl entities are
# organized in subfolders and have their testbenches in a tb subfolders.)
set files [glob                                                                \
    ../vhdl/*.vhdl                                                             \
    ../vhdl/**/*.vhdl ../vhdl/**/tb/*.vhdl                                     \
    ../vhdl/**/**/*.vhdl ../vhdl/**/**/tb/*.vhdl                               \
]

# List the entities in the order that they should be compiled. (This assumes
# entity file and entity itself have the same name.)
set entities {
    "example"

    "safe_io"
    "mul_10"
    "fixed_pwm"
    
    "signed_to_unsigned"
    "bin_to_bcd"
    "bcd_to_bin"
    "bcd_to_7seg"

    "inc"

    "dac"

    "lut_sine"
    "sine_wave"
    "delta_phase"
    "phase_acc"
    "amplitude"
    "gain"
    "offset"
    "dds"
    
    "geni"
}

# List the testbenches in the order that they should be compiled and executed.
# (This assumes testbench file and entity have the same name.)
set testbenches {
    "example_tb"
    
    "safe_io_tb"
    "mul_10_tb"
    "fixed_pwm_tb"

    "signed_to_unsigned_tb"
    "bin_to_bcd_tb"
    "bcd_to_bin_tb"

    "inc_tb"

    "dac_tb"

    "sine_wave_tb"
    "delta_phase_tb"
    "phase_acc_tb"
    "amplitude_tb"
    "gain_tb"
    "offset_tb"
    "dds_tb"
}

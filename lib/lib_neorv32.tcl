# Depending on global variable $::lib_target, either all design files are added
# to quartus project, or all design file entities are compiled with questasim /
# modelsim.

# Name of the library.
set lib_name "neorv32"

# Gather all available vhdl source files.
set lib_files [glob                                                            \
    ../lib/neorv32/rtl/core/*.vhd                                              \
    ../lib/neorv32/rtl/core/**/*.vhd                                           \
    ../vhdl/neorv32_debug_dtm_intel/*.vhd                                      \
    ../vhdl/gcd/*.vhd                                                          \
]

# Filter out the default dtm, we use our own custom Intel specific dtm.
set lib_files [lsearch -inline -all -not $lib_files *neorv32_debug_dtm.vhd]

# Filter out the default cfu, we supply our own custom function unit.
set lib_files [lsearch -inline -all -not $lib_files */core/neorv32_cpu_cp_cfu.vhd]

# List the entities in the order that they should be compiled. For example if
# you put "counter" a file named "counter.vhd{l}" is searched for.
set lib_entities {
    "neorv32_package"
    "neorv32_imem.entity"
    "neorv32_imem.default"
    "neorv32_dmem.entity"
    "neorv32_dmem.default"
    "neorv32_xirq"
    "neorv32_xip"
    "neorv32_wishbone"
    "neorv32_wdt"
    "neorv32_uart"
    "neorv32_twi"
    "neorv32_trng"
    "neorv32_top"
    "neorv32_sysinfo"
    "neorv32_spi"
    "neorv32_sdi"
    "neorv32_pwm"
    "neorv32_onewire"
    "neorv32_neoled"
    "neorv32_mtime"
    "neorv32_icache"
    "neorv32_gptmr"
    "neorv32_gpio"
    "neorv32_fifo"
    "neorv32_debug_dtm.intel"
    "neorv32_debug_dm"
    "neorv32_cpu_regfile"
    "neorv32_cpu_decompressor"
    "neorv32_cpu_cp_shifter"
    "neorv32_cpu_cp_muldiv"
    "neorv32_cpu_cp_fpu"
    "neorv32_cpu_cp_cfu"
    "neorv32_cpu_cp_bitmanip"
    "neorv32_cpu_control"
    "neorv32_cpu_bus"
    "neorv32_cpu_alu"
    "neorv32_cpu"
    "neorv32_cfs"
    "neorv32_busswitch"
    "neorv32_bus_keeper"
    "neorv32_bootloader_image"
    "neorv32_boot_rom"
    "neorv32_application_image"
}

# Add design files to quartus project.
if {[string equal $::lib_target "quartus"]} {
    # Set design files. (This adds ALL known .vhd/.vhdl files.)
    foreach lib_ent $lib_entities {
        set lib_file [lsearch -inline -glob $lib_files "*$lib_ent.vhd"]
        set_global_assignment -name VHDL_FILE $lib_file -library $lib_name
    }
}

# Add entities to modelsim / questasim compilation database.
if {[string equal $::lib_target "sim"]} {
    # Add library
    vlib $lib_name
    vmap work $lib_name
    # Compile the entity files.
    foreach lib_ent $lib_entities {
        quietly set lib_file [lsearch -inline -glob $lib_files "*$lib_ent.vhd"]
        echo "Compiling entity $lib_ent from file $lib_file"
        vcom -quiet $lib_file
    }
}

# Depending on global variable $::lib_target, either all design files are added
# to quartus project, or all design file entities are compiled with questasim /
# modelsim.

# Name of the library.
set lib_name "sdram_fpga"

# Gather all available vhdl source files.
set lib_files [glob                                                            \
    ../lib/sdram-fpga/*.vhd*                                                   \
]

# List the entities in the order that they should be compiled. For example if
# you put "counter" a file named "counter.vhd{l}" is searched for.
set lib_entities {
    "sdram"
}

# Add design files to quartus project.
if {[string equal $::lib_target "quartus"]} {
    # Set design files. (This adds ALL known .vhd/.vhdl files.)
    foreach lib_ent $lib_entities {
        set lib_file [lsearch -inline -glob $lib_files "*$lib_ent.vhd*"]
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
        quietly set lib_file [lsearch -inline -glob $lib_files "*$lib_ent.vhd*"]
        echo "Compiling entity $lib_ent from file $lib_file"
        vcom -quiet $lib_file
    }
}

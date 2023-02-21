# Load Quartus II Tcl project package
package require ::quartus::project

# Create project
project_new "top" -overwrite

# Assign family, device, and top-level entity
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE15F23C8
set_global_assignment -name TOP_LEVEL_ENTITY top

# Default settings
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS [expr {[get_environment_info -num_logical_processors] / 2}]

# Add library design files.
set ::lib_target "quartus"
source ../lib/libs.tcl

# Get definitions of files and entities.
source ../scripts/files.tcl

# Set design files. (This adds ALL known .vhdl files.)
foreach ent $entities {
    set file [lsearch -inline -glob $files "*/$ent.vhd*"]
    set_global_assignment -name VHDL_FILE $file
}

# Pin assignments. (Source: https://gecko-wiki.ti.bfh.ch/gecko4education:start)
source ../scripts/io_assignment/io_assignment.tcl

# Close project
export_assignments
project_close

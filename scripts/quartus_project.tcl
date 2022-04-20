# Load Quartus II Tcl project package
package require ::quartus::project

# Create project
project_new "geni" -overwrite

# Assign family, device, and top-level entity
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE15F23C8
set_global_assignment -name TOP_LEVEL_ENTITY geni

# Default settings
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS [expr {[get_environment_info -num_logical_processors] / 2}]

# Get definitions of files and entities.
source ../scripts/files.tcl

# Set design files. (This adds ALL known .vhdl files.)
foreach ent $entities {
    set file [lsearch -inline -glob $files "*$ent.vhdl"]
    set_global_assignment -name VHDL_FILE $file
}

# Pin assignments. (Source: https://gecko-wiki.ti.bfh.ch/gecko4education:start)
source ../scripts/io_assignment/io_assignment.tcl

# Close project
export_assignments
project_close

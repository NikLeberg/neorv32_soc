# last argument should be the testbench entity
set ent [lindex $argv end]

# Get definitions of files and entities.
quietly source ../scripts/files.tcl

# add all available signals from testbench and dut
add wave -divider testbench
add wave *
add wave -divider dut
catch {add wave dut/*}

# If a dedicated tcl script for this testbench exists, source it.
quietly set tcl_file [lsearch -inline -glob $tcl_files "*/$ent.tcl"]
if {$tcl_file ne ""} {
    quietly source $tcl_file
}

# only show short names of signals
config wave -signalnamewidth 1

# run simulation until stop, break or wait
run -all

# go to wave panel and zoom to the full extend
view wave
wave zoom full

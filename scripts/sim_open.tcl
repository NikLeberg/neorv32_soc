# as first argument the testbench_entity should be given
set ent [lindex $argv 0]

# load simulation of given entity
vsim -t ns -debugDB $ent

# add all available signals from testbench and dut
add wave -divider testbench
add wave *
add wave -divider dut
catch {add wave dut/*}

# only show short names of signals
config wave -signalnamewidth 1

# run simulation until stop, break or wait
run -all

# go to wave panel and zoom to the full extend
view wave
wave zoom full

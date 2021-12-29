# run: "vsim -do ../scripts/tests/gui.do <testbench_entity>" from ../modelsim folder

# as first argument the testbench_entity should be given
set tb [lindex $argv 0]

# load simulation of given testbench_entity
vsim $tb

# add all available signals from testbench and dut
add wave -divider testbench
add wave *
add wave -divider dut
add wave dut/*

# run simulation until stop, break or wait
run -all

# go to wave panel and zoom to the full extend
view wave
wave zoom full

# only show short names of signals
config wave -signalnamewidth 1

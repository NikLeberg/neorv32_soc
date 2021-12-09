# run: "vsim -c -do ../scripts/tests/run.do" from ../modelsim folder

# Exit on error
onerror {quit -f}

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Compile the entity files. Order matters!
set files "example"
foreach file $files {
    vcom -pedanticerrors -check_synthesis -fsmverbose w -lint -source ../vhdl/${file}.vhdl
}

# Compile and run the testbenches. (Testbench file and entity need same name.)
set testbenches "example_tb"
foreach testbench $testbenches {
    vcom -2008 -pedanticerrors -check_synthesis -lint -source ../vhdl/${testbench}.vhdl
    vsim -c $testbench
}

# Run simulation
run -all
quit -f
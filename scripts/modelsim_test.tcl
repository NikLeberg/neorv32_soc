# Exit with code 1 on error
onerror {quit -code 1}

# Exit with code 1 on break (gets triggered on assertion failure)
onbreak {quit -code 1}

# Get definitions of files and entities.
quietly source ../scripts/files.tcl

# Compile and run the testbenches.
foreach testbench $testbenches {
    quietly set file [lsearch -inline -glob $files "*/tb/$testbench.vhdl"]
    echo "--------------------------------"
    echo "Compiling testbench $testbench from file $file"
    vcom -quiet -2008 -pedanticerrors -check_synthesis -lint $file
    echo "Running testbench $testbench:"
    vsim -quiet -hazards -t ns -c $testbench
    run -all
}

quit -f

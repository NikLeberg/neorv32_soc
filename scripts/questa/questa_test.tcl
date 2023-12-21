# Exit with code 1 on error
onerror {quit -code 1}

# Exit with code 1 on break (gets triggered on assertion failure)
onbreak {quit -code 1}

# Run the testbenches.
foreach testbench [lreplace $argv 0 3] {
    echo "--------------------------------"
    echo "Running testbench $testbench:"
    vsim -quiet -hazards -t ns -c $testbench
    run -all
}

quit -f

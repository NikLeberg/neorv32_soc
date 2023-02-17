# Exit with code 1 on error
onerror {quit -code 1}

# Exit with code 1 on break
onbreak {quit -code 1}

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Compile library entity files.
set ::lib_target "sim"
source ../lib/libs.tcl

# Get definitions of files and entities.
quietly source ../scripts/files.tcl

# Compile the entity files.
foreach ent $entities {
    quietly set file [lsearch -inline -glob $files "*$ent.vhd*"]
    echo "Compiling entity $ent from file $file"
    vcom -quiet -pedanticerrors -check_synthesis -fsmverbose w -lint $file
}

# Compile the testbench files.
foreach testbench $testbenches {
    quietly set file [lsearch -inline -glob $files "*/tb/$testbench.vhd*"]
    echo "Compiling testbench $testbench from file $file"
    vcom -quiet -2008 -pedanticerrors -check_synthesis -lint $file
}

quit -f

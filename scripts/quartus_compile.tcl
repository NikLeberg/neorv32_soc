# Load Quartus II Tcl project package
package require ::quartus::project

# Open project
project_open "geni"

# Run compile design flow
load_package flow
execute_flow -compile

# Close project
project_close

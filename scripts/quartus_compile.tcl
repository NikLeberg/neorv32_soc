# Load Quartus II Tcl project package
package require ::quartus::project

# Open project
project_open "top"

# Run compile design flow
load_package flow
execute_flow -compile

# Display summary of flow
load_package report
load_report "top"
write_report_panel -file flowsummary.log "Flow Summary"
set fd [open "flowsummary.log" "r"]
puts [read $fd]
close $fd

# Close project
project_close

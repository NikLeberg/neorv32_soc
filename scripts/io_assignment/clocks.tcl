# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the Clock port
# of your top entity
#set_location_assignment PIN_T22 -to <ENTITY_PORT_NAME_CONNECTED_TO_CLOCK_12MHZ>
set_location_assignment PIN_T1 -to <ENTITY_PORT_NAME_CONNECTED_TO_CLOCK_50MHZ>

# Here the sdc-file will be included
set_global_assignment -name SDC_FILE clocks_sdc.tcl

# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the Output port
# of your top entity
set_location_assignment PIN_U14 -to xip_csn_o
# set_location_assignment PIN_U13 -to <ENTITY_PORT_NAME_CONNECTED_TO_FLASH_NHOLD_IO3>
set_location_assignment PIN_V13 -to xip_clk_o
set_location_assignment PIN_W13 -to xip_sdi_i
set_location_assignment PIN_V14 -to xip_sdo_o
# set_location_assignment PIN_W14 -to <ENTITY_PORT_NAME_CONNECTED_TO_FLASH_NWP_IO2>

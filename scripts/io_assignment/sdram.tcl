# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the Output port
# of your top entity
set_location_assignment PIN_N5 -to sdram_addr[0]
set_location_assignment PIN_N6 -to sdram_addr[1]
set_location_assignment PIN_P4 -to sdram_addr[2]
set_location_assignment PIN_P5 -to sdram_addr[3]
set_location_assignment PIN_W6 -to sdram_addr[4]
set_location_assignment PIN_V7 -to sdram_addr[5]
set_location_assignment PIN_V6 -to sdram_addr[6]
set_location_assignment PIN_V5 -to sdram_addr[7]
set_location_assignment PIN_V1 -to sdram_addr[8]
set_location_assignment PIN_V4 -to sdram_addr[9]
set_location_assignment PIN_U2 -to sdram_addr[10]
set_location_assignment PIN_U8 -to sdram_addr[11]
set_location_assignment PIN_V2 -to sdram_addr[12]

set_location_assignment PIN_M6 -to sdram_ba[0]
set_location_assignment PIN_M7 -to sdram_ba[1]

set_location_assignment PIN_M1  -to sdram_d[0]
set_location_assignment PIN_M2  -to sdram_d[1]
set_location_assignment PIN_M3  -to sdram_d[2]
set_location_assignment PIN_N1  -to sdram_d[3]
set_location_assignment PIN_N2  -to sdram_d[4]
set_location_assignment PIN_P1  -to sdram_d[5]
set_location_assignment PIN_P2  -to sdram_d[6]
set_location_assignment PIN_P3  -to sdram_d[7]
set_location_assignment PIN_W1  -to sdram_d[8]
set_location_assignment PIN_W2  -to sdram_d[9]
set_location_assignment PIN_Y1  -to sdram_d[10]
set_location_assignment PIN_Y2  -to sdram_d[11]
set_location_assignment PIN_Y3  -to sdram_d[12]
set_location_assignment PIN_AA1 -to sdram_d[13]
set_location_assignment PIN_AB3 -to sdram_d[14]
set_location_assignment PIN_AA4 -to sdram_d[15]

set_location_assignment PIN_R1 -to sdram_dqm[0]
set_location_assignment PIN_V3 -to sdram_dqm[1]

set_location_assignment PIN_U7  -to sdram_cke
set_location_assignment PIN_AA3 -to sdram_clk
set_location_assignment PIN_M5  -to sdram_n_cas
set_location_assignment PIN_M4  -to sdram_n_ras
set_location_assignment PIN_U1  -to sdram_n_cs
set_location_assignment PIN_R2  -to sdram_n_we

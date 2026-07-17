create_clock -period 40.000 -name sys_clk [get_ports sys_clk]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports sys_clk]

#uart
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports uart_rx]

set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS33} [get_ports en_485]



set_property -dict {PACKAGE_PIN P6 IOSTANDARD LVCMOS33} [get_ports test_tx]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports test_rx]
#Flash
set_property -dict {PACKAGE_PIN R22 IOSTANDARD LVCMOS33} [get_ports flash_miso]
set_property -dict {PACKAGE_PIN P22 IOSTANDARD LVCMOS33} [get_ports flash_mosi]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports flash_cs_n]

#LED
set_property -dict {PACKAGE_PIN AB2 IOSTANDARD LVCMOS33} [get_ports erase_led]
set_property -dict {PACKAGE_PIN Y3 IOSTANDARD LVCMOS33} [get_ports program_led]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]
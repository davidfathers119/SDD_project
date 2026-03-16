###############################################################################
# ZC702 LED Control System - Pin Constraints
# File: led_pins.xdc
# Date: 2026-03-16
# Reference: UG850 Table 1-27 - GPIO Header Connections to XC7Z020 SoC at U1
#            UG850 Table 1-25 - GPIO DIP Switch Connections
# Verified: Based on successful project D:\VIVADO\test\LED_right_to_left
###############################################################################

###############################################################################
# LED輸出引腳約束 (ZC702 User LED - GPIO Header J62/J63)
###############################################################################
# 重要: I/O Standard必須為LVCMOS25 (2.5V)，不是LVCMOS33！
###############################################################################

# LED 0 - PMOD1_0 (J63.1)
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS25} [get_ports {LED[0]}]

# LED 1 - PMOD1_1 (J63.3)
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS25} [get_ports {LED[1]}]

# LED 2 - PMOD1_2 (J63.5)
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS25} [get_ports {LED[2]}]

# LED 3 - PMOD1_3 (J63.7)
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS25} [get_ports {LED[3]}]

# LED 4 - PMOD2_0 (J62.1)
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS25} [get_ports {LED[4]}]

# LED 5 - PMOD2_1 (J62.2)
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS25} [get_ports {LED[5]}]

# LED 6 - PMOD2_2 (J62.3)
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS25} [get_ports {LED[6]}]

# LED 7 - PMOD2_3 (J62.4)
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS25} [get_ports {LED[7]}]

###############################################################################
# DIP開關輸入約束 (Mode Selection)
###############################################################################
# Reference: Table 1-25 - GPIO DIP Switch Connections to XC7Z020 SoC at U1
###############################################################################

# DIP Switch 0 - GPIO_DIP_SW0 (Mode bit 0)
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS25} [get_ports {DIP[0]}]

# DIP Switch 1 - GPIO_DIP_SW1 (Mode bit 1)
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS25} [get_ports {DIP[1]}]

###############################################################################
# Mode Encoding:
# DIP[1:0] = 00 : Mode A - Binary Display (0-255)
# DIP[1:0] = 01 : Mode B - Single LED Mode (0-8)
# DIP[1:0] = 10 : Mode C - Progressive Mode (0-8)
# DIP[1:0] = 11 : Reserved (Invalid)
###############################################################################

###############################################################################
# 時序約束（可選）
###############################################################################

# 如果需要對LED設置特定的輸出延遲，可以取消下面的註解
# set_output_delay -clock [get_clocks clk_fpga_0] -min 0.000 [get_ports LED*]
# set_output_delay -clock [get_clocks clk_fpga_0] -max 5.000 [get_ports LED*]

###############################################################################
# 注意事項
###############################################################################
# 1. 以上引腳根據ZC702 User Guide (UG850) 定義
# 2. LED為高電平點亮
# 3. IOSTANDARD為LVCMOS33（3.3V邏輯電平）
# 4. 如果使用不同版本的ZC702或自定義板卡，請根據硬體原理圖修改
###############################################################################

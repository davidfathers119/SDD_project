###############################################################################
# Vivado Block Design自動化腳本
# File: create_bd_design.tcl
# Purpose: 自動建立LED控制系統的Block Design
# Usage: 在Vivado Tcl Console中執行: source create_bd_design.tcl
###############################################################################

# 檢查是否有專案開啟
if {[current_project -quiet] eq ""} {
    puts "錯誤: 請先開啟或創建一個Vivado專案"
    return
}

# 設置變數
set design_name "led_control_system"
set bd_name "led_bd"

puts "開始建立Block Design: $bd_name"

# 創建Block Design
create_bd_design $bd_name

# 創建當前BD的引用
current_bd_design $bd_name

###############################################################################
# 添加ZYNQ7 PS IP
###############################################################################
puts "添加ZYNQ7 Processing System..."
set zynq_inst [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]

# 配置ZYNQ7
puts "配置ZYNQ7..."
set_property -dict [list \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.0} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
] $zynq_inst

# 運行Block Automation
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $zynq_inst

###############################################################################
# 選項1: 使用AXI GPIO (簡單方法)
###############################################################################
puts "添加AXI GPIO..."
set gpio_inst [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0]

# 配置GPIO為8位輸出
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {8} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {0} \
] $gpio_inst

# 使GPIO輸出為外部端口
set gpio_port [create_bd_port -dir O -from 7 -to 0 LED]
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_ports LED]

###############################################################################
# 添加AXI互連
###############################################################################
puts "添加AXI互連..."
set axi_interconnect [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0]
set_property -dict [list CONFIG.NUM_MI {1}] $axi_interconnect

# 連接時鐘和複位
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}} \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

###############################################################################
# 地址分配
###############################################################################
puts "分配地址空間..."
assign_bd_address

# 設置GPIO基地址（可選，Vivado會自動分配）
# set_property offset 0x41200000 [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_gpio_0_Reg}]
# set_property range 64K [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_gpio_0_Reg}]

###############################################################################
# 驗證設計
###############################################################################
puts "驗證Block Design..."
validate_bd_design

###############################################################################
# 保存並關閉
###############################################################################
puts "保存Block Design..."
save_bd_design

puts ""
puts "=========================================="
puts "Block Design創建完成！"
puts "=========================================="
puts ""
puts "下一步："
puts "1. 查看Block Design: Open Block Design"
puts "2. 創建HDL Wrapper: 右鍵BD -> Create HDL Wrapper"
puts "3. 添加約束文件: led_pins.xdc"
puts "4. 生成Bitstream: Generate Bitstream"
puts "5. 導出硬體: File -> Export -> Export Hardware"
puts ""
puts "重要: 記錄AXI GPIO的基地址，用於C代碼中！"
puts "可以在Address Editor中查看"
puts ""

###############################################################################
# 注意事項
###############################################################################
# 1. 如果使用自定義IP (vitris_LED.vhd)，請先將其打包為IP
# 2. 本腳本使用AXI GPIO作為示例，更簡單易用
# 3. 如需使用自定義IP，請修改上述代碼，添加自定義IP而非AXI GPIO
###############################################################################

# 如果需要使用自定義IP，可以取消下面的註解並修改
# 
# # 添加自定義LED控制IP
# set custom_ip [create_bd_cell -type ip -vlnv user.org:user:vitris_LED:1.0 vitris_LED_0]
# 
# # 連接AXI接口
# apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
#     -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/vitris_LED_0/S_AXI} ...} \
#     [get_bd_intf_pins vitris_LED_0/S_AXI]
# 
# # 使LED輸出為外部端口
# set led_port [create_bd_port -dir O -from 7 -to 0 LED]
# connect_bd_net [get_bd_pins vitris_LED_0/LED] [get_bd_ports LED]

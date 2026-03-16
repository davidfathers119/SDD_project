# 硬體規格書 (Hardware Specification)
## LED控制系統 - ZC702開發板

**文檔版本**: 1.0  
**日期**: 2026年3月16日  
**狀態**: ✅ 已確認  
**參考文檔**: UG850 - ZC702 Evaluation Board User Guide

---

## 1. 硬體平台

### 1.1 開發板規格
| 項目 | 規格 |
|------|------|
| **開發板型號** | Xilinx ZC702 Evaluation Board |
| **SoC晶片** | XC7Z020 Zynq-7000 (U1) |
| **處理器** | Dual-core ARM Cortex-A9 (PS端) |
| **可編程邏輯** | Artix-7 FPGA (PL端) |
| **參考手冊** | file://172.16.0.14/.../ug850-zc702-eval-bd.pdf |

### 1.2 已驗證的參考專案
| 專案 | 路徑 | 驗證狀態 |
|------|------|----------|
| UART測試 | `D:\VIVADO\test\uart_test` | ✅ 成功 |
| LED流水燈 | `D:\VIVADO\test\LED_right_to_left` | ✅ 成功 |

---

## 2. LED硬體規格

### 2.1 LED配置
| 參數 | 規格 |
|------|------|
| **LED數量** | 8個 (User LED) |
| **連接方式** | GPIO Header (PMOD Connector) |
| **驅動電平** | 高電平點亮 (Active High) |
| **參考表格** | Table 1-27: GPIO Header Connections to XC7Z020 SoC at U1 |

### 2.2 LED腳位定義

**基於已驗證配置** (`D:\VIVADO\test\LED_right_to_left\ZC702_constraints.xdc`)

| LED編號 | FPGA腳位 | Net Name | I/O Standard | GPIO Header | 說明 |
|---------|----------|----------|--------------|-------------|------|
| LED[0] | E15 | PMOD1_0 | LVCMOS25 | J63.1 | User LED 0 |
| LED[1] | D15 | PMOD1_1 | LVCMOS25 | J63.3 | User LED 1 |
| LED[2] | W17 | PMOD1_2 | LVCMOS25 | J63.5 | User LED 2 |
| LED[3] | W5  | PMOD1_3 | LVCMOS25 | J63.7 | User LED 3 |
| LED[4] | V7  | PMOD2_0 | LVCMOS25 | J62.1 | User LED 4 |
| LED[5] | W10 | PMOD2_1 | LVCMOS25 | J62.2 | User LED 5 |
| LED[6] | P18 | PMOD2_2 | LVCMOS25 | J62.3 | User LED 6 |
| LED[7] | P17 | PMOD2_3 | LVCMOS25 | J62.4 | User LED 7 |

### 2.3 LED電氣特性
| 參數 | 規格 |
|------|------|
| **電壓標準** | LVCMOS25 (2.5V) |
| **邏輯高電平** | 2.5V |
| **邏輯低電平** | 0V |
| **驅動能力** | 標準FPGA I/O驅動 |

⚠️ **重要**: I/O Standard必須設置為**LVCMOS25**，不是LVCMOS33！

---

## 3. DIP開關硬體規格

### 3.1 DIP開關配置
| 參數 | 規格 |
|------|------|
| **開關數量** | 2個 (用於模式選擇) |
| **連接方式** | GPIO Header |
| **讀取方式** | 輸入模式 (Input) |
| **參考表格** | Table 1-25: GPIO DIP Switch Connections to XC7Z020 SoC at U1 |

### 3.2 DIP開關腳位定義

| DIP編號 | FPGA腳位 | Net Name | I/O Standard | 說明 |
|---------|----------|----------|--------------|------|
| DIP[0] | W6 | GPIO_DIP_SW0 | LVCMOS25 | 模式選擇位元0 |
| DIP[1] | W7 | GPIO_DIP_SW1 | LVCMOS25 | 模式選擇位元1 |

### 3.3 DIP開關模式編碼

| DIP[1] | DIP[0] | 編碼 | 功能模式 |
|--------|--------|------|----------|
| 0 | 0 | 00 | 模式A: 二進制顯示 (0-255) |
| 0 | 1 | 01 | 模式B: 單燈模式 (0-8) |
| 1 | 0 | 10 | 模式C: 累進模式 (0-8) |
| 1 | 1 | 11 | 保留 (無效模式) |

### 3.4 DIP開關電氣特性
| 參數 | 規格 |
|------|------|
| **電壓標準** | LVCMOS25 (2.5V) |
| **邏輯高電平** | 2.5V (開關ON) |
| **邏輯低電平** | 0V (開關OFF) |
| **上拉/下拉** | 根據板卡設計 |
| **讀取方式** | GPIO輸入 |

---

## 4. UART硬體規格

### 3.1 UART連接器
| 參數 | 規格 |
|------|------|
| **連接器型號** | USB Connector J17 |
| **連接器類型** | USB Type-B |
| **參考表格** | Table 1-15: USB Connector J17 Pin Assignments |
| **驗證狀態** | ✅ 已在 `uart_test` 專案中驗證通過 |

### 3.2 UART引腳定義
| J17 Pin | Net Name | Signal | CP2103G Pin | 說明 |
|---------|----------|---------|-------------|------|
| VBUS | USB_UART_VBUS | +5V VBUS Powered | - | 電源 |
| D_N | USB_UART_D_N | Bidirectional differential serial data (N-side) | 4 | 差分數據負端 |
| D_P | USB_UART_D_P | Bidirectional differential serial data (P-side) | 3 | 差分數據正端 |
| GND | USB_UART_GND | Signal ground | 2, 29 | 地線 |

### 3.3 UART通訊參數
| 參數 | 設定值 | 狀態 |
|------|--------|------|
| **鮑率** | 115200 bps | ✅ 已驗證 |
| **數據位** | 8 bits | 標準配置 |
| **校驗位** | None | 標準配置 |
| **停止位** | 1 bit | 標準配置 |
| **流控** | None | 標準配置 |
| **通訊格式** | 8-N-1 | - |

### 3.4 USB-UART晶片
| 項目 | 規格 |
|------|------|
| **晶片型號** | Silicon Labs CP2103G |
| **驅動需求** | CP210x USB to UART Bridge VCP Drivers |
| **Windows支持** | Windows 7/8/10/11 |
| **COM端口** | 自動分配 (需在設備管理器中確認) |

---

## 5. 時鐘與複位

### 5.1 系統時鐘
| 參數 | 規格 | 來源 |
|------|------|------|
| **主時鐘源** | 200MHz 差分時鐘 | ZC702板載晶振 |
| **FPGA時鐘** | 可配置 (通常100MHz) | PS_CLK_FPGA_0 |
| **時鐘輸入腳位** | D18 (CK_P), C19 (CK_N) | 來自LED專案 |
| **I/O Standard** | LVDS_25 | 差分標準 |

```vhdl
-- 時鐘約束範例（來自已驗證專案）
set_property PACKAGE_PIN D18 [get_ports CK_P]
set_property PACKAGE_PIN C19 [get_ports CK_N]
set_property IOSTANDARD LVDS_25 [get_ports {CK_P CK_N}]
create_clock -name sys_clk -period 5.000 [get_ports CK_P]
```

### 5.2 複位信號
| 參數 | 規格 | 來源 |
|------|------|------|
| **複位按鈕** | G19 | 來自LED專案 |
| **I/O Standard** | LVCMOS25 | - |
| **複位極性** | 按下為低 | Active Low |

---

## 6. PS-PL介面

### 6.1 AXI總線配置
| 參數 | 規格 |
|------|------|
| **介面類型** | AXI4-Lite |
| **數據寬度** | 32 bits |
| **地址寬度** | 32 bits |
| **時鐘源** | FCLK_CLK0 (100MHz) |
| **複位** | FCLK_RESET0_N |

### 6.2 PS端配置需求
| 配置項 | 設定 |
|--------|------|
| **M_AXI_GP0** | 啟用 (Enable) - 用於LED控制 |
| **GPIO (EMIO)** | 啟用 - 用於讀取DIP開關 |
| **UART1** | 啟用 (MIO 48..49 或 J17) |
| **FCLK_CLK0** | 100 MHz |
| **DDR** | 根據ZC702自動配置 |

### 6.3 GPIO EMIO配置
需要配置2個GPIO輸入用於DIP開關：
- GPIO_0[0] ← DIP[0] (W6)
- GPIO_0[1] ← DIP[1] (W7)

### 6.4 AXI暫存器對應表 ⭐

**基地址**: 需要在Vivado中配置（建議: 0x43C00000）

| 暫存器名稱 | 偏移量 | 存取類型 | 位元定義 | 說明 |
|------------|--------|----------|----------|------|
| **LED_CONTROL** | 0x00 | Write | [7:0] LED控制 | 寫入LED狀態值 |
| **STATUS** | 0x04 | Read | [8] 更新完成<br>[7:0] LED狀態回讀 | 讀取LED狀態和完成標誌 |

#### 6.4.1 LED_CONTROL暫存器 (偏移量 0x00)
**功能**: 控制8個LED的亮滅狀態

| 位元 | 名稱 | 類型 | 復位值 | 說明 |
|------|------|------|--------|------|
| [31:8] | 保留 | - | 0x000000 | 未使用，讀取為0 |
| [7] | LED7_CTL | W | 0 | LED7控制 (1=亮, 0=滅) |
| [6] | LED6_CTL | W | 0 | LED6控制 (1=亮, 0=滅) |
| [5] | LED5_CTL | W | 0 | LED5控制 (1=亮, 0=滅) |
| [4] | LED4_CTL | W | 0 | LED4控制 (1=亮, 0=滅) |
| [3] | LED3_CTL | W | 0 | LED3控制 (1=亮, 0=滅) |
| [2] | LED2_CTL | W | 0 | LED2控制 (1=亮, 0=滅) |
| [1] | LED1_CTL | W | 0 | LED1控制 (1=亮, 0=滅) |
| [0] | LED0_CTL | W | 0 | LED0控制 (1=亮, 0=滅) |

**使用範例** (PS端C代碼):
```c
#define LED_BASE_ADDR    0x43C00000
#define LED_CONTROL_REG  (LED_BASE_ADDR + 0x00)

// 點亮LED0, LED2, LED4 (0b00010101 = 0x15)
Xil_Out32(LED_CONTROL_REG, 0x15);
```

#### 6.4.2 STATUS暫存器 (偏移量 0x04) ⭐ 重要
**功能**: 讀取LED更新完成狀態和當前LED值

| 位元 | 名稱 | 類型 | 復位值 | 說明 |
|------|------|------|--------|------|
| [31:9] | 保留 | - | 0x000000 | 未使用，讀取為0 |
| [8] | **UPDATE_DONE** | R | 1 | **LED更新完成標誌**<br>1 = 更新完成，可接受新命令<br>0 = 更新進行中，請等待 |
| [7] | LED7_STAT | R | 0 | LED7當前狀態回讀 |
| [6] | LED6_STAT | R | 0 | LED6當前狀態回讀 |
| [5] | LED5_STAT | R | 0 | LED5當前狀態回讀 |
| [4] | LED4_STAT | R | 0 | LED4當前狀態回讀 |
| [3] | LED3_STAT | R | 0 | LED3當前狀態回讀 |
| [2] | LED2_STAT | R | 0 | LED2當前狀態回讀 |
| [1] | LED1_STAT | R | 0 | LED1當前狀態回讀 |
| [0] | LED0_STAT | R | 0 | LED0當前狀態回讀 |

**使用範例** (PS端C代碼):
```c
#define STATUS_ADDR              (LED_BASE_ADDR + 0x04)
#define LED_UPDATE_COMPLETE_BIT  (1 << 8)

// 檢查LED更新是否完成
bool is_led_update_complete() {
    uint32_t status = Xil_In32(STATUS_ADDR);
    return (status & LED_UPDATE_COMPLETE_BIT) != 0;
}

// 讀取當前LED狀態
uint8_t get_current_led_status() {
    uint32_t status = Xil_In32(STATUS_ADDR);
    return status & 0xFF;
}

// 等待LED更新完成
void wait_led_update_complete() {
    while (!is_led_update_complete()) {
        usleep(100);  // 等待100us
    }
}

// 安全的LED更新函數
void set_led_safe(uint8_t value) {
    // 寫入新值
    Xil_Out32(LED_CONTROL_REG, value);
    
    // 等待完成
    wait_led_update_complete();
    
    // 驗證寫入（可選）
    uint8_t readback = get_current_led_status();
    if (readback != value) {
        printf("警告: LED狀態不一致！\r\n");
    }
}
```

#### 6.4.3 PL端VHDL實現需求

**狀態機控制LED更新**:
```vhdl
signal led_reg : std_logic_vector(7 downto 0);
signal update_done : std_logic;

-- LED更新邏輯
process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            led_reg <= (others => '0');
            update_done <= '1';  -- 初始為完成狀態
        elsif axi_write_valid = '1' and axi_addr = 0x00 then
            -- 開始LED更新
            update_done <= '0';
            led_reg <= axi_write_data(7 downto 0);
            -- 可能需要幾個時鐘週期來更新物理LED
        else
            -- 更新完成（實際可能需要延遲幾個週期）
            update_done <= '1';
        end if;
    end if;
end process;

-- 輸出到物理LED
led_output <= led_reg;

-- 狀態暫存器讀取
process(axi_addr, update_done, led_reg)
begin
    if axi_addr = 0x04 then
        axi_read_data(31 downto 9) <= (others => '0');
        axi_read_data(8) <= update_done;
        axi_read_data(7 downto 0) <= led_reg;
    else
        axi_read_data <= (others => '0');
    end if;
end process;
```

#### 6.4.4 時序要求

| 參數 | 要求 |
|------|------|
| **AXI寫入延遲** | ≤ 2個時鐘週期 |
| **LED更新時間** | ≤ 5個時鐘週期 |
| **狀態回讀延遲** | 1個時鐘週期 |
| **總響應時間** | ≤ 100ns @ 100MHz |

#### 6.4.5 暫存器存取範例

**寫入LED (模式B，點亮LED2)**:
```c
// 模式B: 輸入3，點亮LED2
// LED控制值 = 1 << (3-1) = 0b00000100 = 0x04
Xil_Out32(LED_CONTROL_REG, 0x04);

// 等待完成
while (!(Xil_In32(STATUS_ADDR) & (1<<8))) {
    // 輪詢等待
}

// 驗證
uint8_t status = Xil_In32(STATUS_ADDR) & 0xFF;
if (status == 0x04) {
    printf("LED更新成功\r\n");
}
```

**模式A二進制顯示**:
```c
// 模式A: 輸入85
// LED控制值 = 0b01010101 = 0x55
Xil_Out32(LED_CONTROL_REG, 0x55);
wait_led_update_complete();
```

---

## 7. 電源與功耗

### 7.1 電源需求
| 配置項 | 設定 |
|--------|------|
| **M_AXI_GP0** | 啟用 (Enable) |
| **UART1** | 啟用 (MIO 48..49 或 J17) |
| **FCLK_CLK0** | 100 MHz |
| **DDR** | 根據ZC702自動配置 |

---

## 7. 電源與功耗

### 7.1 電源需求
| 電源 | 電壓 | 用途 |
|------|------|------|
| **主電源** | 12V DC | ZC702主電源輸入 |
| **VCCO** | 2.5V | GPIO Bank電源 |
| **VCCIO** | 各種電壓 | 根據Bank配置 |

### 7.2 功耗要求
| 項目 | 規格 |
|------|------|
| **功耗限制** | 無特殊限制 |
| **散熱** | ZC702標準散熱片 |
| **工作溫度** | 室溫環境 |

---

## 8. 物理連接檢查清單

### 8.1 必須連接
- [x] 12V電源適配器
- [x] USB線連接至J17 (UART)
- [x] JTAG線 (用於程式下載)
- [x] DIP開關設定 (位於GPIO Header)

### 8.2 跳線與開關設置
| 項目 | 設定 | 說明 |
|------|------|------|
| **啟動模式 (SW16)** | JTAG Mode | 開發階段使用 |
| **電源開關 (SW1)** | ON | 主電源 |

### 8.3 LED及DIP開關位置
- 所有8個User LED位於PMOD連接器J62和J63上
- DIP開關位於板卡上，標診SW0和SW1
- 確保物理連接正確

---

## 9. 已驗證配置參考

### 9.1 LED流水燈專案
**路徑**: `D:\VIVADO\test\LED_right_to_left\ZC702_constraints.xdc`

```tcl
# 已驗證的LED腳位配置
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS25} [get_ports {Led[0]}]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS25} [get_ports {Led[1]}]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS25} [get_ports {Led[2]}]
set_property -dict {PACKAGE_PIN W5  IOSTANDARD LVCMOS25} [get_ports {Led[3]}]
set_property -dict {PACKAGE_PIN V7  IOSTANDARD LVCMOS25} [get_ports {Led[4]}]
set_property -dict {PACKAGE_PIN W10 IOSTANDARD LVCMOS25} [get_ports {Led[5]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS25} [get_ports {Led[6]}]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS25} [get_ports {Led[7]}]

# DIP開關配置（本專案新增）
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS25} [get_ports {DIP[0]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS25} [get_ports {DIP[1]}]
```

### 9.2 UART專案
**路徑**: `D:\VIVADO\test\uart_test`
- UART通訊已驗證成功
- 鮑率: 115200 bps
- 無需額外配置

---

## 10. 硬體驗收標準

### 10.1 LED測試
- [ ] 所有8個LED可獨立控制
- [ ] 高電平點亮，低電平熄滅
- [ ] 無閃爍或不穩定現象
- [ ] LED亮度均勻

### 10.2 UART測試
- [ ] PC端可正確識別COM端口
- [ ] 能夠發送和接收數據
- [ ] 鮑率115200穩定通訊
- [ ] 無亂碼或丟包

### 10.3 DIP開關測試
- [ ] 能正確讀取DIP開關狀態
- [ ] 模式切換功能正常
- [ ] DIP狀態與系統行為一致

### 10.4 系統整合測試
- [ ] PS-PL通訊正常
- [ ] AXI寫入操作成功
- [ ] 響應時間 < 100ms
- [ ] 長時間穩定運行

---

## 11. 注意事項與限制

### 11.1 關鍵注意事項
1. ⚠️ **I/O電壓**: GPIO Bank使用**2.5V**，必須設置為**LVCMOS25**
2. ⚠️ **腳位衝突**: 確保bLED和DIP腳位與其他功能不衝突
3. ⚠️ **USB驅動**: Windows需安裝CP210x驅動程式
4. ⚠️ **啟動模式**: 開發階段使用JTAG模式
5. ⚠️ **DIP開關**: 確保在系統上電前設定好初始模式

### 11.2 已知限制
- 無特殊限制
- 標準ZC702開發板功能

### 11.3 參考文檔
- UG850: ZC702 Evaluation Board User Guide
- UG585: Zynq-7000 Technical Reference Manual
- 已驗證專案: `uart_test`, `LED_right_to_left`

---

## 11. 修訂歷史

| 版本 | 日期 | 修改者 | 說明 |
|------|------|--------|------|
| 1.0 | 2026-03-16 | - | 基於用戶提供資訊和已驗證專案建立 |

---

**文檔狀態**: ✅ 已確認，可用於代碼生成  
**批准狀態**: 待用戶確認  
**下一步**: 等待用戶確認後進入功能需求規格階段

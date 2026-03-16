# AXI暫存器對應表
## LED控制系統 - 快速參考

**文檔版本**: 1.0  
**日期**: 2026年3月16日  
**基地址**: 0x43C00000 (建議，需在Vivado中配置)  
**介面**: AXI4-Lite, 32-bit

---

## 暫存器摘要表

| 偏移量 | 暫存器名稱 | 存取 | 復位值 | 功能說明 |
|--------|------------|------|--------|----------|
| 0x00 | LED_CONTROL | W | 0x00 | 寫入8位LED控制值 |
| 0x04 | STATUS | R | 0x0100 | 讀取更新完成標誌和LED狀態 |

---

## 詳細暫存器定義

### 暫存器0: LED_CONTROL (偏移量 0x00)

**功能**: 控制8個LED的亮滅狀態  
**存取類型**: 只寫 (Write-Only)  
**復位值**: 0x00000000

#### 位元定義

```
  31                           8   7   6   5   4   3   2   1   0
 ┌─────────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───┐
 │          保留 (0)            │ L7│ L6│ L5│ L4│ L3│ L2│ L1│ L0│
 └─────────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───┘
```

| 位元 | 名稱 | 說明 |
|------|------|------|
| [31:8] | 保留 | 寫入被忽略，讀取為0 |
| [7] | LED7_CTL | LED7控制 (1=亮, 0=滅) |
| [6] | LED6_CTL | LED6控制 (1=亮, 0=滅) |
| [5] | LED5_CTL | LED5控制 (1=亮, 0=滅) |
| [4] | LED4_CTL | LED4控制 (1=亮, 0=滅) |
| [3] | LED3_CTL | LED3控制 (1=亮, 0=滅) |
| [2] | LED2_CTL | LED2控制 (1=亮, 0=滅) |
| [1] | LED1_CTL | LED1控制 (1=亮, 0=滅) |
| [0] | LED0_CTL | LED0控制 (1=亮, 0=滅) |

#### 使用範例

**C語言 (Xilinx)**:
```c
#define LED_BASE_ADDR    0x43C00000
#define LED_CONTROL_REG  (LED_BASE_ADDR + 0x00)

// 全部點亮
Xil_Out32(LED_CONTROL_REG, 0xFF);

// 全部熄滅
Xil_Out32(LED_CONTROL_REG, 0x00);

// 只點亮LED0和LED7
Xil_Out32(LED_CONTROL_REG, 0x81);

// 二進制顯示85 (0b01010101)
Xil_Out32(LED_CONTROL_REG, 85);
```

---

### 暫存器1: STATUS (偏移量 0x04) ⭐ 重要

**功能**: 讀取LED更新完成狀態和當前LED值  
**存取類型**: 只讀 (Read-Only)  
**復位值**: 0x00000100 (UPDATE_DONE = 1)

#### 位元定義

```
  31                         9  8   7   6   5   4   3   2   1   0
 ┌───────────────────────────┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
 │        保留 (0)            │UPD│ S7│ S6│ S5│ S4│ S3│ S2│ S1│ S0│
 └───────────────────────────┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
                              ↑
                        更新完成標誌
```

| 位元 | 名稱 | 說明 |
|------|------|------|
| [31:9] | 保留 | 讀取為0 |
| **[8]** | **UPDATE_DONE** | **LED更新完成標誌** ⭐<br>1 = 更新完成，可接受新命令<br>0 = 更新進行中，請等待 |
| [7] | LED7_STAT | LED7當前狀態回讀 (1=亮, 0=滅) |
| [6] | LED6_STAT | LED6當前狀態回讀 |
| [5] | LED5_STAT | LED5當前狀態回讀 |
| [4] | LED4_STAT | LED4當前狀態回讀 |
| [3] | LED3_STAT | LED3當前狀態回讀 |
| [2] | LED2_STAT | LED2當前狀態回讀 |
| [1] | LED1_STAT | LED1當前狀態回讀 |
| [0] | LED0_STAT | LED0當前狀態回讀 |

#### 使用範例

**C語言 (Xilinx)**:
```c
#define STATUS_ADDR              (LED_BASE_ADDR + 0x04)
#define LED_UPDATE_COMPLETE_BIT  (1 << 8)

// 檢查更新是否完成
bool is_led_update_complete() {
    uint32_t status = Xil_In32(STATUS_ADDR);
    return (status & LED_UPDATE_COMPLETE_BIT) != 0;
}

// 讀取當前LED狀態（低8位）
uint8_t get_led_status() {
    uint32_t status = Xil_In32(STATUS_ADDR);
    return (uint8_t)(status & 0xFF);
}

// 等待更新完成
void wait_led_update() {
    while (!is_led_update_complete()) {
        usleep(100);  // 等待100微秒
    }
}

// 完整的LED更新函數
void set_led_with_wait(uint8_t value) {
    // 1. 寫入新值
    Xil_Out32(LED_CONTROL_REG, value);
    
    // 2. 等待完成
    wait_led_update();
    
    // 3. 驗證（可選）
    uint8_t readback = get_led_status();
    if (readback != value) {
        printf("警告: LED狀態驗證失敗！\r\n");
        printf("  預期: 0x%02X, 實際: 0x%02X\r\n", value, readback);
    }
}
```

---

## 操作流程

### 標準LED更新流程

```
┌─────────────────────────────────────────────────────┐
│ 1. 檢查STATUS[8]是否為1 (更新完成)                   │
│    └─ 如果為0，等待完成                              │
├─────────────────────────────────────────────────────┤
│ 2. 寫入LED_CONTROL暫存器 (偏移量0x00)                │
│    └─ STATUS[8]自動變為0 (更新進行中)               │
├─────────────────────────────────────────────────────┤
│ 3. 等待STATUS[8]變回1 (更新完成)                    │
│    └─ 通常需要 5-10個時鐘週期 (50-100ns @ 100MHz)   │
├─────────────────────────────────────────────────────┤
│ 4. (可選) 讀取STATUS[7:0]驗證LED狀態                │
│    └─ 應該與寫入值一致                              │
└─────────────────────────────────────────────────────┘
```

### 時序圖

```
時鐘:      __/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__
AXI寫入:   ___________/‾‾‾‾‾‾‾\__________________________
UPDATE_DONE: ‾‾‾‾‾‾‾‾‾‾\\______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                        ^      ^
                        |      |
                    開始更新  完成更新
                    (2-5個時鐘週期)
```

---

## 常見使用模式

### 模式A: 二進制顯示 (輸入0-255)

```c
// 用戶輸入: 85
int value = 85;  // 0b01010101

if (value >= 0 && value <= 255) {
    set_led_with_wait((uint8_t)value);
}
```

### 模式B: 單燈模式 (輸入0-8)

```c
// 用戶輸入: 3 → 點亮LED2
int index = 3;
uint8_t led_value;

if (index == 0) {
    led_value = 0x00;  // 全滅
} else if (index >= 1 && index <= 8) {
    led_value = 1 << (index - 1);  // 單個LED
} else {
    // 錯誤，超出範圍
    return;
}

set_led_with_wait(led_value);
```

### 模式C: 累進模式 (輸入0-8)

```c
// 用戶輸入: 5 → LED0-LED4全亮
int count = 5;
uint8_t led_value;

if (count == 0) {
    led_value = 0x00;
} else if (count >= 1 && count <= 8) {
    led_value = (1 << count) - 1;  // 累進點亮
} else {
    // 錯誤，超出範圍
    return;
}

set_led_with_wait(led_value);
```

---

## 錯誤檢測與處理

### 超時檢測

```c
#define AXI_TIMEOUT_MS  10  // 10毫秒超時

bool wait_led_update_timeout(uint32_t timeout_ms) {
    uint32_t start_time = get_time_ms();
    
    while (!is_led_update_complete()) {
        if (get_time_ms() - start_time > timeout_ms) {
            return false;  // 超時
        }
        usleep(100);
    }
    
    return true;  // 成功
}

// 使用
if (!wait_led_update_timeout(AXI_TIMEOUT_MS)) {
    printf("錯誤: LED更新超時！\r\n");
    printf("可能原因:\r\n");
    printf("  - PL端未正確初始化\r\n");
    printf("  - AXI總線連接問題\r\n");
    printf("  - 時鐘配置錯誤\r\n");
}
```

### 狀態驗證

```c
void set_led_verified(uint8_t value) {
    // 寫入
    Xil_Out32(LED_CONTROL_REG, value);
    
    // 等待完成
    if (!wait_led_update_timeout(AXI_TIMEOUT_MS)) {
        printf("錯誤: LED更新超時\r\n");
        return;
    }
    
    // 驗證
    uint8_t readback = get_led_status();
    if (readback != value) {
        printf("警告: LED狀態不一致\r\n");
        printf("  寫入: 0x%02X (%s)\r\n", 
               value, byte_to_binary_str(value));
        printf("  回讀: 0x%02X (%s)\r\n", 
               readback, byte_to_binary_str(readback));
    }
}
```

---

## PL端實現參考

### VHDL狀態機

```vhdl
-- 暫存器
signal led_reg : std_logic_vector(7 downto 0);
signal update_done : std_logic;

-- LED更新狀態機
process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            led_reg <= (others => '0');
            update_done <= '1';  -- 初始完成狀態
        elsif axi_write_valid = '1' and axi_addr = X"00000000" then
            -- 開始更新
            update_done <= '0';
            led_reg <= axi_write_data(7 downto 0);
            -- 實際可能需要幾個週期來穩定輸出
        else
            -- 更新完成
            update_done <= '1';
        end if;
    end if;
end process;

-- 輸出
led_output <= led_reg;

-- 狀態暫存器讀取
process(axi_addr, update_done, led_reg)
begin
    case axi_addr is
        when X"00000004" =>  -- STATUS暫存器
            axi_read_data(31 downto 9) <= (others => '0');
            axi_read_data(8) <= update_done;
            axi_read_data(7 downto 0) <= led_reg;
        when others =>
            axi_read_data <= (others => '0');
    end case;
end process;
```

---

## 快速參考

### 暫存器地址
```c
#define LED_BASE_ADDR       0x43C00000
#define LED_CONTROL_REG     (LED_BASE_ADDR + 0x00)  // 只寫
#define STATUS_REG          (LED_BASE_ADDR + 0x04)  // 只讀
```

### 常用函數
```c
// 簡單寫入（不等待）
Xil_Out32(LED_CONTROL_REG, value);

// 安全寫入（等待完成）
set_led_with_wait(value);

// 檢查完成
if (is_led_update_complete()) { ... }

// 讀取當前狀態
uint8_t current = get_led_status();
```

### 數值轉換表

| 十進制 | 十六進制 | 二進制 | LED7-0顯示 |
|--------|----------|--------|------------|
| 0 | 0x00 | 00000000 | ⚫⚫⚫⚫⚫⚫⚫⚫ |
| 1 | 0x01 | 00000001 | ⚫⚫⚫⚫⚫⚫⚫🟢 |
| 15 | 0x0F | 00001111 | ⚫⚫⚫⚫🟢🟢🟢🟢 |
| 85 | 0x55 | 01010101 | ⚫🟢⚫🟢⚫🟢⚫🟢 |
| 170 | 0xAA | 10101010 | 🟢⚫🟢⚫🟢⚫🟢⚫ |
| 255 | 0xFF | 11111111 | 🟢🟢🟢🟢🟢🟢🟢🟢 |

---

## 注意事項

### ⚠️ 重要提醒

1. **必須等待UPDATE_DONE**: 在發送下一個LED命令前，必須檢查STATUS[8]=1
2. **基地址配置**: 需要在Vivado的Block Design中設置正確的基地址
3. **存取對齊**: AXI寫入必須是32位對齊的地址
4. **只寫/只讀**: LED_CONTROL只能寫，STATUS只能讀
5. **驗證狀態**: 建議在調試階段驗證回讀值與寫入值一致

### 🐛 常見問題

**問**: 為什麼需要UPDATE_DONE標誌？  
**答**: 防止用戶輸入過快導致LED更新混亂，確保每次更新完成後再接受新命令。

**問**: UPDATE_DONE需要多久從0變回1？  
**答**: 通常5-10個時鐘週期，@ 100MHz約50-100ns，對用戶來說幾乎瞬間。

**問**: 如果不檢查UPDATE_DONE會怎樣？  
**答**: 可能導致前一個LED更新未完成就被新命令覆蓋，造成LED閃爍或狀態錯誤。

---

**文檔版本**: 1.0  
**維護者**: LED控制系統開發團隊  
**最後更新**: 2026-03-16  
**參考**: 硬體規格書 v1.0, 功能需求規格書 v1.0

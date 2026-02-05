# FPGA TTL 通訊故障排除指南

## 當前配置
- **轉換器**: USB to RS485/TTL (FTDI FT232RL)
- **波特率**: 38400
- **數據格式**: 8N1 (8 data bits, No parity, 1 stop bit)
- **VHDL設定**: F_SET="111" (38400 baud @ 25MHz clock)

## 檢查清單

### 1. 硬體接線檢查
**TTL 側接線** (連接到 FPGA):
```
轉換器 TTL  →  FPGA
--------------------------
TX (TXD)    →  RX (接收)
RX (RXD)    →  TX (發送)
GND         →  GND
VCC         →  (如需供電給FPGA，否則不連)
```

⚠️ **重要**: TX 和 RX 必須交叉連接！
- 轉換器的 TX 接 FPGA 的 RX
- 轉換器的 RX 接 FPGA 的 TX

### 2. 電壓準位確認
- FTDI FT232RL TTL 輸出: **3.3V** 或 **5V** (需確認跳線設定)
- FPGA I/O 電壓: 檢查您的 FPGA 開發板規格
- 如果電壓不匹配，需要電平轉換器

### 3. FPGA 檢查
- [ ] FPGA 是否已正確燒錄程式？
- [ ] FPGA 時鐘是否正確？(應為 25MHz 或 50MHz)
- [ ] FPGA 電源是否正常？
- [ ] FPGA 的 RS232 link 模組是否正確實例化？

### 4. Windows COM 埠設定
在裝置管理員中確認:
1. COM 埠是否正確識別
2. 進階設定:
   - 波特率: 38400
   - 數據位: 8
   - 停止位: 1
   - 同位檢查: 無
   - 流量控制: 無

### 5. VB 程式診斷

#### 測試步驟:
1. **查看 LOG 訊息**:
   - 檢查是否有 `[TX]` 訊息（表示已發送）
   - 檢查是否有 `[RX]` 訊息（表示有接收到資料）
   - 檢查是否有 `[Packet]` 訊息（表示封包解析成功）
   - 檢查是否有錯誤訊息

2. **資料傳輸測試**:
   ```
   [TX] 應顯示: bytes=526 head=AA-55-02-00-...
   [RX] 應顯示: chunk=... total=... head=...
   ```

3. **如果完全沒有 [RX] 訊息**:
   - FPGA 沒有回應
   - 接線問題
   - FPGA 程式未正確運行

4. **如果有 [RX] 但沒有 [Packet]**:
   - 封包格式錯誤
   - 可能是 FPGA 回傳格式不符

### 6. 簡易回送測試 (Loopback Test)

**測試轉換器本身**:
1. 將轉換器的 TX 和 RX 短接
2. 執行 VB 程式發送
3. 應該會立即收到相同的資料

如果回送測試成功，表示轉換器正常，問題在 FPGA 側。

### 7. 使用示波器/邏輯分析儀 (如有)
- 量測 TX 線上是否有資料傳輸
- 量測 RX 線上是否有 FPGA 回應
- 確認波特率是否正確 (每個 bit 約 26µs @ 38400baud)

### 8. FPGA 時鐘頻率確認
RS232 模組需要 **25MHz** 時鐘才能正確產生 38400 baud:
- ✅ 您的 FPGA 是 **50MHz**，已在 [fft_system_top.vhd](src/vhdl/fft_system_top.vhd) 中自動除以 2
- ✅ 時鐘除頻器在第 93-100 行：
  ```vhdl
  process(clk50, rst_n)
  begin
      if rst_n = '0' then
          clk25 <= '0';
      elsif rising_edge(clk50) then
          clk25 <= not clk25;  -- Toggle: 50MHz → 25MHz
      end if;
  end process;
  ```
- ✅ 所有模組 (rs232_link, fft_core) 都使用 `clk25`

**重要**: 確認您在 Quartus 中：
1. Pin Assignment 將板子的時鐘輸入指定給 `clk50` 接腳
2. 時鐘約束設定為 50MHz
3. `rst_n` 接腳正確連接（通常接按鈕或開關，注意是 active-low）

### 9. 建議的除錯步驟順序
1. ✅ 確認接線 (TX↔RX 交叉)
2. ✅ 確認 GND 連接
3. ✅ 執行回送測試
4. ✅ 確認 FPGA 已燒錄且運行
5. ✅ 確認時鐘頻率
6. ✅ 檢查 VB LOG 訊息
7. ✅ 如有可能，用示波器確認信號

## 修改後的 VB 程式改進

已完成以下改進:
1. ✅ 增加相位圖表顯示
2. ✅ 調整視窗大小為 1400x800
3. ✅ 改善圖表佈局 (左邊時域，右邊上下分別為振幅和相位)
4. ✅ Y 軸自動縮放
5. ✅ 新增 Phase 計算函數
6. ✅ 修正 VB 變數名稱衝突錯誤 (BC30290)

## FPGA 配置確認

### VHDL 代碼狀態
✅ **已正確配置**：
- 時鐘輸入: 50MHz (`clk50`)
- 自動除頻為 25MHz (`clk25`) 供 RS232 使用
- UART 波特率: 38400 (F_SET="111")
- 數據格式: 8N1
- 封包格式: Header (0xAA55) + Length (16-bit LE) + Payload

### Quartus 專案檢查清單
請確認以下設定：

1. **Pin Assignment** (Assignment Editor):
   ```
   clk50     → 您的板子時鐘輸入接腳 (通常標示為 CLK 或 CLOCK)
   rst_n     → 復位按鈕/開關 (active-low: 按下=0, 釋放=1)
   uart_rx   → TTL 轉換器的 TX 接腳連接
   uart_tx   → TTL 轉換器的 RX 接腳連接
   led_status[7..0] → LED 指示燈 (選配，用於除錯)
   ```

2. **TimeQuest Timing Analyzer**:
   - 建立 50MHz 時鐘約束: `create_clock -period 20ns [get_ports clk50]`

3. **編譯流程**:
   ```
   Analysis & Synthesis → OK
   Fitter → OK
   Assembler → 生成 .sof 檔案
   Programmer → 燒錄到 FPGA
   ```

## 常見問題

**Q: 為什麼 Y 軸顯示幾千的數值？**
A: 因為 ADC/DAC 使用 16-bit signed integer (-32768 ~ 32767)，這是正常的數值範圍。

**Q: 圖表太大看不到相位？**
A: 已修正，現在視窗更大，且相位圖獨立顯示在右下方。

**Q: FPGA 完全沒反應？**
A: 請依照上述檢查清單逐項檢查，最常見的問題是 TX/RX 沒有交叉連接。

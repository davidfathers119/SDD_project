# FFT 訊號處理系統 - 技術規格文件

## 版本資訊

| 版本 | 日期 | 作者 | 說明 |
|------|------|------|------|
| 1.0 | 2026-01-25 | | 初版規格 |

---

## 1. 系統需求規格

### 1.1 功能需求

#### FR-001：波形輸入與顯示
- **需求描述**：VB 程式須能接收或產生時域訊號，並即時顯示波形
- **輸入**：使用者輸入參數或匯入資料檔
- **輸出**：時域波形圖表
- **優先級**：High

#### FR-002：RS-232 資料傳輸（VB → FPGA）
- **需求描述**：VB 透過 RS-232 傳送時域資料至 FPGA
- **輸入**：時域資料陣列
- **輸出**：序列位元流
- **優先級**：High

#### FR-003：FFT 硬體運算
- **需求描述**：FPGA 執行 FFT 運算，將時域轉換為頻域
- **輸入**：時域複數資料
- **輸出**：頻域複數資料（實部、虛部）
- **優先級**：High

#### FR-004：RS-232 資料傳輸（FPGA → VB）
- **需求描述**：FPGA 透過 RS-232 傳送 FFT 結果至 VB
- **輸入**：頻域資料陣列
- **輸出**：序列位元流
- **優先級**：High

#### FR-005：頻譜顯示與分析
- **需求描述**：VB 程式接收頻域資料並繪製頻譜圖
- **輸入**：頻域資料
- **輸出**：頻譜圖表、分析結果
- **優先級**：High

### 1.2 效能需求

#### PR-001：FFT 運算時間
- **指標**：1024 點 FFT 運算時間 < 10 ms
- **測試方法**：硬體計時器量測

#### PR-002：資料傳輸延遲
- **指標**：單向傳輸延遲 < 500 ms（含封包處理）
- **測試方法**：時間戳記比對

#### PR-003：系統吞吐率
- **指標**：完整處理週期（傳送→運算→接收）< 2 秒
- **測試方法**：端到端計時

#### PR-004：精確度
- **指標**：FFT 運算誤差 < 1%（相對標準軟體實作）
- **測試方法**：已知訊號比對

### 1.3 介面需求

#### IR-001：RS-232 通訊參數
- **鮑率**：38400 bps（目前匯入的 RS232 driver 最高支援 38400；若要 115200 需修改 driver 的 divisor/設定介面）
- **資料位元**：8 bits
- **停止位元**：1 bit
- **同位檢查**：None / Even / Odd（可配置）
- **流量控制**：None / Hardware (RTS/CTS)

#### IR-002：VB 使用者介面
- **主視窗**：包含波形顯示區、控制按鈕、參數設定
- **波形圖表**：時域波形與頻域頻譜
- **狀態列**：顯示連線狀態、處理進度

---

## 2. FPGA 硬體規格

### 2.1 FFT 核心模組規格

#### 模組名稱：`fft_core`

##### 泛型參數 (Generic)
| 參數名稱 | 型別 | 預設值 | 說明 |
|----------|------|--------|------|
| FFT_SIZE | integer | 256 | FFT 點數（本專案固定為 256） |
| DATA_WIDTH | integer | 16 | 資料位元寬度（16-bit 固定點數） |
| TWIDDLE_WIDTH | integer | 16 | 旋轉因子位元寬度 |

##### 連接埠 (Port)
| 訊號名稱 | 方向 | 寬度 | 說明 |
|----------|------|------|------|
| clk | in | 1 | 系統時鐘 |
| rst_n | in | 1 | 低電位重置 |
| start | in | 1 | 開始 FFT 運算 |
| data_re_in | in | DATA_WIDTH | 輸入資料（實部） |
| data_im_in | in | DATA_WIDTH | 輸入資料（虛部） |
| data_valid_in | in | 1 | 輸入資料有效 |
| data_re_out | out | DATA_WIDTH | 輸出資料（實部） |
| data_im_out | out | DATA_WIDTH | 輸出資料（虛部） |
| data_valid_out | out | 1 | 輸出資料有效 |
| busy | out | 1 | FFT 運算中 |
| done | out | 1 | FFT 完成 |

##### 功能描述
- 實作 Radix-2 DIT (Decimation In Time) FFT 演算法
- 使用位元反轉輸入順序
- 蝴蝶運算採用流水線架構
- 旋轉因子儲存於 ROM
- 支援固定點數運算

### 2.2 RS-232 接收模組規格

#### 模組名稱：`RS232_R2`（匯入既有 driver）

##### 連接埠（依 rs232_r2.vhd）
| 訊號名稱 | 方向 | 寬度 | 說明 |
|----------|------|------|------|
| Clk | in | 1 | Driver 時鐘（建議 25 MHz；由 50 MHz 除 2 取得） |
| Reset | in | 1 | Active-low reset（Reset='0' 重置） |
| DL | in | 2 | Data length："11"=8-bit |
| ParityN | in | 3 | Parity："0xx"=None |
| StopN | in | 2 | Stop："00"=1 stop bit |
| F_Set | in | 3 | 鮑率設定（driver 內建表，最高 38400） |
| Status_s | out | 3 | (2)=Rx_B_Empty(=1 表示 buffer 有新資料), (1)=Parity Error, (0)=Overwrite |
| Rx_R | in | 1 | 主控器讀取/清除握手（以 0->1 觸發清除） |
| RD | in | 1 | UART RX 線 |
| RxDs | out | 8 | 接收到的 byte |

##### 功能描述
- 以內建 divisor 表產生取樣時脈
- 偵測起始位元、接收資料、選配 parity
- 使用 1-byte buffer 與 Status_s(2) 做資料可用提示

#### 包裝模組：`rs232_link`
- 將 `RS232_R2/RS232_T1` 封裝成更好用的 byte streaming 介面：`rx_valid` 單拍脈波、`tx_ready` 準備好可送。

### 2.3 RS-232 傳送模組規格

#### 模組名稱：`RS232_T1`（匯入既有 driver）

##### 連接埠（依 rs232_t1.vhd）
| 訊號名稱 | 方向 | 寬度 | 說明 |
|----------|------|------|------|
| Clk | in | 1 | Driver 時鐘（建議 25 MHz；由 50 MHz 除 2 取得） |
| Reset | in | 1 | Active-low reset（Reset='0' 重置） |
| DL | in | 2 | Data length："11"=8-bit |
| ParityN | in | 3 | Parity："0xx"=None |
| StopN | in | 2 | Stop："00"=1 stop bit |
| F_Set | in | 3 | 鮑率設定（driver 內建表，最高 38400） |
| Status_s | out | 2 | (1)=Tx_B_Empty（0=可載入新資料）, (0)=TxO_W（overwrite） |
| TX_W | in | 1 | 送出請求（對 '1' 的上升緣載入 TXData） |
| TXData | in | 8 | 要送出的 byte |
| TX | out | 1 | UART TX 線 |

##### 功能描述
- 1-byte buffer：主控器在 `Status_s(1)=0` 時可送下一個 byte
- `TX_W` 單拍觸發載入並開始傳送

### 2.4 資料緩衝模組規格

#### 模組名稱：`data_buffer`

##### 泛型參數
| 參數名稱 | 型別 | 預設值 | 說明 |
|----------|------|--------|------|
| BUFFER_SIZE | integer | 1024 | 緩衝區大小 |
| DATA_WIDTH | integer | 16 | 資料寬度 |

##### 連接埠
| 訊號名稱 | 方向 | 寬度 | 說明 |
|----------|------|------|------|
| clk | in | 1 | 系統時鐘 |
| rst_n | in | 1 | 低電位重置 |
| wr_en | in | 1 | 寫入致能 |
| wr_data | in | DATA_WIDTH | 寫入資料 |
| rd_en | in | 1 | 讀取致能 |
| rd_data | out | DATA_WIDTH | 讀取資料 |
| full | out | 1 | 緩衝區滿 |
| empty | out | 1 | 緩衝區空 |
| count | out | log2(BUFFER_SIZE) | 資料筆數 |

### 2.5 頂層模組規格

#### 模組名稱：`fft_system_top`

##### 連接埠
| 訊號名稱 | 方向 | 寬度 | 說明 |
|----------|------|------|------|
| clk | in | 1 | 系統時鐘 (50 MHz) |
| rst_n | in | 1 | 外部重置按鈕 |
| uart_rx | in | 1 | RS-232 接收 |
| uart_tx | out | 1 | RS-232 傳送 |
| led_status | out | 8 | 狀態 LED |

##### 內部狀態機
```
IDLE → RECEIVE_DATA → WAIT_COMPLETE → FFT_COMPUTE → SEND_RESULT → IDLE
```

---

## 3. VB 軟體規格

### 3.1 主程式功能模組

#### 模組：MainForm
- **功能**：主要使用者介面與流程控制
- **建議使用**：Windows Forms（易於串列埠控制）
- **介面元件**：
  - 波形顯示區（時域）- 使用 OxyPlot 或 LiveCharts
  - 頻譜顯示區（頻域）- 使用 OxyPlot 或 LiveCharts
  - 控制按鈕（產生波形、傳送、接收）
  - 參數設定區
  - 狀態顯示區

#### 模組：RS232Comm
- **功能**：RS-232 通訊處理
- **建議使用**：System.IO.Ports.SerialPort 類別
- **主要方法**：
  - `OpenPort()` - 開啟串列埠
  - `ClosePort()` - 關閉串列埠
  - `SendData(data As Byte())` - 傳送資料
  - `ReceiveData() As Byte()` - 接收資料
  - `ConfigPort(baudRate, dataBits, parity, stopBits)` - 設定通訊參數
- **事件處理**：DataReceived 事件（非同步接收）

#### 模組：PlotModule
- **功能**：波形與頻譜繪圖
- **推薦套件**：
  - OxyPlot (NuGet: OxyPlot.WindowsForms)
  - LiveCharts (NuGet: LiveCharts.WinForms)
  - ScottPlot (NuGet: ScottPlot.WinForms) - 高效能即時繪圖
- **主要方法**：
  - `PlotTimeDomain(data As Double())` - 繪製時域波形
  - `PlotFrequencyDomain(freqData As Complex())` - 繪製頻域頻譜
  - `ClearPlot()` - 清除圖表
  - `SavePlot(filename As String)` - 儲存圖表

#### 模組：WaveGenerator
- **功能**：波形產生
- **主要方法**：
  - `GenerateSine(freq, amplitude, samples)` - 產生正弦波
  - `GenerateSquare(freq, amplitude, samples)` - 產生方波
  - `GenerateTriangle(freq, amplitude, samples)` - 產生三角波
  - `LoadFromFile(filename)` - 從檔案載入

### 3.2 資料格式規範

#### 時域資料封包格式（VB → FPGA）

```
+----------+----------+----------+----------+----------+----------+
| Header   | Length   | Data[0]  | Data[1]  | ...      | Checksum |
| (2 bytes)| (2 bytes)| (4 bytes)| (4 bytes)| Data[N-1]| (2 bytes)|
+----------+----------+----------+----------+----------+----------+
```

- **Header**：0xAA55（固定標頭）
- **Length**：資料點數（N）
- **Data[i]**：16-bit 實部 + 16-bit 虛部（two's complement signed）
- **端序**：Little-endian（每個 16-bit：先送低位元組，再送高位元組）
- **Checksum**：XOR 檢查碼

#### 頻域資料封包格式（FPGA → VB）

```
+----------+----------+----------+----------+----------+----------+
| Header   | Length   | Freq[0]  | Freq[1]  | ...      | Checksum |
| (2 bytes)| (2 bytes)| (4 bytes)| (4 bytes)| Freq[N-1]| (2 bytes)|
+----------+----------+----------+----------+----------+----------+
```

- **Header**：0x55AA（固定標頭）
- **Length**：頻率點數（N）
- **Freq[i]**：16-bit 實部 + 16-bit 虛部（或振幅 + 相位）
- **端序**：Little-endian（每個 16-bit：先送低位元組，再送高位元組）
- **Checksum**：XOR 檢查碼

### 3.3 使用者介面規範

#### 主視窗配置
```
+----------------------------------------------------------+
|  檔案(F)  編輯(E)  工具(T)  說明(H)                      |
+----------------------------------------------------------+
|  [產生波形] [傳送至FPGA] [接收結果] [清除]              |
+----------------------------------------------------------+
|  參數設定區                                               |
|  FFT 點數: [1024 ▼]  取樣頻率: [____] Hz                |
|  COM 埠: [COM3 ▼]    鮑率: [38400 ▼]                    |
+----------------------------------------------------------+
|  時域波形                    |  頻域頻譜                  |
|                              |                            |
|  [波形圖表區域]              |  [頻譜圖表區域]            |
|                              |                            |
|                              |                            |
+------------------------------+----------------------------+
|  狀態: 就緒                                     [進度條]  |
+----------------------------------------------------------+
```

---

## 4. 通訊協定規格

### 4.1 握手協定

#### 初始化握手
1. VB 傳送：`0xFF 0xFE` (INIT_REQUEST)
2. FPGA 回應：`0xFE 0xFF` (INIT_ACK)
3. VB 確認：`0xAA 0xAA` (READY)

#### 資料傳輸握手
1. VB 傳送：`0xAA 0x55` (DATA_START) + 資料封包
2. FPGA 每接收 128 bytes 回應：`0xCC` (ACK)
3. VB 傳送完成：`0x55 0xAA` (DATA_END)
4. FPGA 確認：`0xDD` (RECEIVED)

#### FFT 完成通知
1. FPGA 傳送：`0x55 0xAA` (FFT_DONE)
2. VB 回應：`0xEE` (READY_TO_RECEIVE)
3. FPGA 傳送結果封包
4. VB 確認：`0xFF` (RECEIVED)

### 4.2 錯誤處理

#### 錯誤代碼
- `0xE0`：Checksum 錯誤
- `0xE1`：封包格式錯誤
- `0xE2`：資料長度錯誤
- `0xE3`：逾時
- `0xE4`：緩衝區溢位

---

## 9. 實作狀態（Bring-up）

目前 repo 內提供可綜合的串列與資料流骨架，方便先把 VB↔FPGA↔VB 跑通：

- [FFT/src/vhdl/rs232_r2.vhd](FFT/src/vhdl/rs232_r2.vhd)、[FFT/src/vhdl/rs232_t1.vhd](FFT/src/vhdl/rs232_t1.vhd)：既有 RS232 driver
- [FFT/src/vhdl/rs232_link.vhd](FFT/src/vhdl/rs232_link.vhd)：握手包裝（避免同一 byte 讀三次）
- [FFT/src/vhdl/fft_system_top.vhd](FFT/src/vhdl/fft_system_top.vhd)：封包解析 + 回傳資料（目前回傳為「原樣 echo」，FFT 由 stub 佔位）
- [FFT/src/vhdl/fft_core_stub.vhd](FFT/src/vhdl/fft_core_stub.vhd)：FFT core 佔位（後續替換成真正 256-point FFT）

#### 重傳機制
- 最大重傳次數：3 次
- 逾時時間：5 秒
- 重傳前延遲：100 ms

---

## 5. 資源使用估計

### 5.1 FPGA 資源（Altera Cyclone III EP3C40Q240）

| 資源類型 | 使用量（估計） | 可用量 | 使用率 |
|----------|--------|--------|--------|
| Logic Elements (LEs) | ~8000 | 39,600 | ~20% |
| Memory Bits | ~65,536 | 1,161,216 | ~6% |
| Embedded Multipliers | ~12 | 126 | ~10% |
| PLLs | 1 | 4 | 25% |

### 5.2 記憶體需求

#### FPGA 端
- 輸入緩衝區：256 × 32 bits = 1 KB
- 輸出緩衝區：256 × 32 bits = 1 KB
- 旋轉因子 ROM：256 × 32 bits = 1 KB
- **總計**：約 3 KB

#### VB 端
- 時域資料：256 × 8 bytes = 2 KB
- 頻域資料：256 × 8 bytes = 2 KB
- 圖表緩衝：~1 MB
- **總計**：約 1.02 MB

---

## 6. 測試規格

### 6.1 單元測試

#### FPGA 模組測試
- **FFT 核心**：已知訊號（單頻、多頻、脈衝）
- **RS-232 RX**：各種鮑率與資料模式
- **RS-232 TX**：連續傳送測試
- **資料緩衝**：讀寫衝突測試

#### VB 模組測試
- **波形產生**：各類波形正確性
- **串列通訊**：資料完整性驗證
- **繪圖功能**：圖表正確性

### 6.2 整合測試

| 測試案例 | 輸入 | 預期輸出 | 通過標準 |
|----------|------|----------|----------|
| TC-001 | 1 kHz 正弦波 | 頻譜峰值於 1 kHz | 誤差 < 5% |
| TC-002 | 多頻混合訊號 | 各頻率成分清晰 | SNR > 40 dB |
| TC-003 | 方波訊號 | 基頻與諧波 | 諧波衰減正確 |
| TC-004 | 白雜訊 | 平坦頻譜 | 標準差 < 3 dB |

### 6.3 效能測試

- **延遲測試**：量測端到端延遲時間
- **吞吐量測試**：連續處理 100 次取平均
- **穩定性測試**：連續運行 1000 次無錯誤
- **邊界測試**：最大/最小資料值測試

---

## 7. 開發時程規劃

| 階段 | 工作項目 | 預估時間 | 負責人 |
|------|----------|----------|--------|
| 第一階段 | FPGA FFT 核心開發 | 2 週 | |
| 第二階段 | RS-232 通訊模組開發 | 1 週 | |
| 第三階段 | VB 介面開發 | 2 週 | |
| 第四階段 | 系統整合 | 1 週 | |
| 第五階段 | 測試與除錯 | 2 週 | |
| **總計** | | **8 週** | |

---

## 8. 附錄

### 8.1 參考文獻
- IEEE 754 浮點數標準
- RS-232 標準 (EIA-232)
- Cooley-Tukey FFT 演算法

### 8.2 專有名詞
- **FFT**：Fast Fourier Transform（快速傅立葉轉換）
- **DIT**：Decimation In Time（時域抽取）
- **DIF**：Decimation In Frequency（頻域抽取）
- **Radix-2**：基底為 2 的 FFT 演算法
- **Twiddle Factor**：旋轉因子

### 8.3 修訂歷史

| 版本 | 日期 | 修訂內容 | 修訂者 |
|------|------|----------|--------|
| 1.0 | 2026-01-25 | 初版建立 | |

---

**文件結束**

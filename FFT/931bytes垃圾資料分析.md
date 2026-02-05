# 931 Bytes 垃圾資料問題分析

## 現象
每次 VB 程式啟動並連接 FPGA 後，在發送任何資料之前，就會收到 **固定 931 bytes** 的垃圾資料：
- 開頭：`55-FD`（不是正確的 `55-AA`）
- 內容：重複的模式 `FF-FF-2F-6F-FF-FF-33-33...`
- 數量：始終是 931 bytes

## 已嘗試的解決方案

### 1. VB 端清理緩衝區
- ✅ 實施了循環清理策略（最多 10 輪）
- ❌ 無效：清理階段從未讀到資料（`BytesToRead` 始終為 0）
- 原因：資料通過 `DataReceived` 事件異步到達，不會出現在同步讀取中

### 2. FPGA 添加 data_ready 標誌
- ✅ 實施了 `data_ready` 標誌防止未初始化發送
- ❌ 無效：仍然收到 931 bytes
- 原因：可能 FPGA 初始化時信號值不可靠

### 3. FPGA 重置輸出記憶體
- ❌ 未實施：VHDL 中大型陣列初始化成本高
- 替代方案：使用 `data_ready` 標誌（但無效）

## 可能的根本原因

### 假設 1：FPGA UART TX 緩衝區殘留
- FPGA 燒錄後 UART TX FIFO 中有殘留資料
- Power-on 時這些資料自動發送
- **檢驗方法**：在 Quartus 中檢查 UART 模組的初始化邏輯

### 假設 2：FSM 意外進入 SEND 狀態
- `ps` 信號初始化可能不可靠（Quartus 13.1 舊版本）
- FPGA 在 power-on 時 FSM 可能不在 `WAIT_H1`
- **檢驗方法**：LED[4-7] 應該顯示 FSM 狀態，但用戶未報告 LED 狀態

### 假設 3：UART RX 誤觸發
- FPGA 誤認為收到了資料
- 進入了接收→處理→發送的完整流程
- **檢驗方法**：檢查 LED[7] (RECV_PAYLOAD) 是否在 VB 發送前亮起

### 假設 4：RS232 模組 Bug
- `rs232_link` 或相關模組在初始化時自動發送了一些資料
- **檢驗方法**：需要檢查 rs232_link.vhd 的初始化邏輯

## 931 bytes 的意義

計算：
- 完整封包：2 (header) + 2 (length) + 1024 (payload) = 1028 bytes
- 實際收到：931 bytes
- 差距：1028 - 931 = 97 bytes

可能解釋：
1. FPGA 發送了 97 bytes 後停止（為什麼？）
2. 或者 FPGA 從某個偏移量開始發送

## 建議的下一步

### 立即行動：
1. **檢查 LED 狀態**：讓用戶報告 FPGA power-on 後、VB 連接前的 LED 狀態
   - LED[7] 亮 → FSM 在 RECV_PAYLOAD
   - LED[4] 亮 → FSM 在 START_FFT
   - LED[5] 亮 → FSM 在發送 header
   - LED[6] 亮 → FSM 在發送 payload

2. **FPGA 硬重置**：在 VHDL 中添加手動重置邏輯
   - 連接一個按鈕到 `rst_n`
   - 在 VB 發送前手動重置 FPGA

3. **檢查 rs232_link 模組**：查看 UART 初始化邏輯

### 長期解決：
1. **握手協議**：VB 發送特殊初始化命令，FPGA 確認後才開始正常通信
2. **FPGA 看門狗**：添加超時機制，長時間無活動自動重置 FSM
3. **升級 Quartus**：考慮使用更新版本的 Quartus（如果硬體支援）

## 時間線
- 2026/2/6 02:55 - 仍然收到 931 bytes，所有已知方案無效
- 需要更多診斷資訊（LED 狀態、UART 模組檢查）

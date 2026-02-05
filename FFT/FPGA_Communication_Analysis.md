# FPGA 通訊問題分析報告

## 當前狀態
- **發送**: 1028 bytes (AA-55-00-01 + 256 complex samples)
- **接收**: 931 bytes
- **狀態**: Timeout (15秒)

## 資料分析

### 收到的資料開頭
```
55-FD-FF-FF-FF-FF-2F-6F-FF-FF-33-33-FF-FF-2F-6F-FF-FF-FF-FF-FF-FF-26-F2-FF-A6-E6-FF-26-F2-FF-FF...
```

### 資料解析
1. **第一個 byte: 0x55** ✅ 正確 (TX_HEADER_H1)
2. **第二個 byte: 0xFD** ❌ 錯誤 (應該是 0xAA)
3. **資料重複模式**: 明顯的週期性pattern
4. **總長度**: 931 bytes (不足 1028 bytes)

### 問題診斷

#### 可能原因 1: FPGA FSM 卡住
VHDL `fft_system_top.vhd` 中的 FSM 可能在某個狀態卡住：
- `START_FFT` 狀態的邏輯有重複
- 第 246-253 行和 296-309 行都在處理 FFT 輸入

```vhdl
-- 第 246 行附近
when START_FFT =>
    fft_start <= '1';
    sample_idx <= 0;
    ps <= START_FFT;  -- 這會造成無窮迴圈！
    ...
```

**問題**: `ps <= START_FFT` 讓狀態機停留在同一狀態，永遠不會進入 SEND 階段。

#### 可能原因 2: FPGA 未正確處理接收
VHDL 中接收封包的長度檢查（第 194-200 行）：
```vhdl
length_val := to_integer(unsigned(rx_b & len0));
if length_val = FFT_N then  -- 必須恰好等於 256
    ps <= RECV_PAYLOAD;
else
    ps <= WAIT_H1;
end if;
```

VB發送的length是 `00-01` (little-endian)，在VHDL中解析成：
- `rx_b & len0` = `0x01 & 0x00` = 0x0100 = 256 ✅ 正確

#### 可能原因 3: 傳輸速率問題
- 38400 baud = 3840 bytes/sec
- 1028 bytes 需要 ~267ms
- 但接收只花了 0.3秒就停止，且只收到 931 bytes
- **可能**: FPGA 停止傳輸或傳輸緩衝區滿

## 根本原因

查看 VHDL code 第 240-253 行：

```vhdl
when START_FFT =>
    fft_start <= '1';
    sample_idx <= 0;
    ps <= START_FFT;  -- ❌ 問題在這裡！
    
    fft_in_re <= in_re_mem(0);
    fft_in_im <= in_im_mem(0);
    fft_in_valid <= '1';
    if FFT_N = 1 then
        ps <= SEND_H1;
    else
        sample_idx <= 1;
        ps <= START_FFT;  -- ❌ 又停留在 START_FFT
    end if;
```

**問題**: 狀態機邏輯混亂，`ps` 被多次賦值，最終停留在 `START_FFT`，而後面的程式碼（296-309行）才會推進到 `SEND_H1`。

### 為什麼收到資料？

可能的情況：
1. FPGA 之前的執行殘留資料在 UART TX buffer 中
2. 或者 FPGA 在 reset 後進入異常狀態，亂發資料
3. 資料 `0x55` 開頭可能是某些 debug 輸出或未初始化的記憶體

## 修正方案

### 方案 A: 修正 VHDL START_FFT 狀態機 ⭐ 推薦

需要簡化 `START_FFT` 狀態的邏輯：

```vhdl
when START_FFT =>
    if sample_idx = 0 then
        -- 第一次進入，啟動 FFT
        fft_start <= '1';
        fft_in_re <= in_re_mem(0);
        fft_in_im <= in_im_mem(0);
        fft_in_valid <= '1';
        sample_idx <= 1;
    elsif sample_idx < FFT_N then
        -- 繼續餵資料
        fft_in_re <= in_re_mem(sample_idx);
        fft_in_im <= in_im_mem(sample_idx);
        fft_in_valid <= '1';
        sample_idx <= sample_idx + 1;
    else
        -- 所有資料已送完
        ps <= SEND_H1;
    end if;
```

移除第 296-309 行的重複邏輯。

### 方案 B: 臨時測試 - 回送原始資料

為了先確認通訊正常，可以暫時讓 FPGA 直接回傳接收到的資料（不做FFT）。

在 VHDL `SEND_PAYLOAD` 中已經是這樣做的（第 280-287 行），但因為 FSM 卡在 `START_FFT`，永遠到不了 `SEND_PAYLOAD`。

### 方案 C: VB 端改善容錯 ✅ 已實施

1. ✅ 更寬容的 header 偵測（已修改 ByteStreamParser）
2. ✅ 詳細的 debug trace
3. ✅ 完整的 hex dump

## 立即行動

### 1. 確認 FPGA 狀態
- 檢查 LED 指示燈：
  - `led_status[0]`: RX 資料接收 (應該閃爍)
  - `led_status[1]`: TX ready
  - `led_status[2]`: FFT busy (可能一直亮著 = 卡住)
  - `led_status[3]`: FFT done

### 2. 嘗試 FPGA Reset
按下 reset 按鈕（`rst_n`），確保 FSM 重新開始。

### 3. 修改 VHDL (最終解決方案)
修正 `fft_system_top.vhd` 的 START_FFT 狀態機邏輯。

## 測試資料數值分析

收到的資料中重複出現的數值：
- `FD-FF` = -3
- `2F-6F` = 0x6F2F = 28463  
- `33-33` = 0x3333 = 13107
- `26-F2` = 0xF226 = -3546 (有符號) 或 62246 (無符號)
- `A6-E6` = 0xE6A6 = -6490

這些不像是您發送的 1000Hz 正弦波資料，更像是未初始化的記憶體或之前運行的殘留資料。

## 下一步

1. **立即**: 重新編譯 VB（已有改進的 parser）並重試
2. **短期**: 檢查 FPGA LED 狀態，嘗試 reset
3. **根本解決**: 修正 VHDL START_FFT 狀態機邏輯

您想要我幫您修正 VHDL 代碼嗎？

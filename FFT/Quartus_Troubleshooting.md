# Quartus 13.1 (VHDL) 排錯筆記（SDD FFT 專案）

本文件整理本次在 Quartus II 13.1 Web Edition 編譯 VHDL 專案時遇到的錯誤與修正方式，包含常見的「work library 找不到 entity」、「top entity 重複」、「out 不能讀取」、以及 `quartus_map.exe` 在 elaboration 階段 Access Violation 當機等問題。

> 環境：Quartus II 64-Bit 13.1.0 Build 162 (10/23/2013)

---

## 1) Error (10481): work 找不到 `rs232_link`

### 錯誤訊息

> Error (10481): VHDL Use Clause error … design library "work" does not contain primary unit "rs232_link"

### 原因

`fft_system_top` 內有實例化：

```vhdl
u_link: entity work.rs232_link
```

但 Quartus 專案沒有把 `rs232_link.vhd`（或其相依檔案）加入專案，因此 `work` library 裡根本沒有編譯出 `rs232_link`。

### 解法

1. 在 Quartus：**Project → Add/Remove Files in Project…**
2. 確認以下 VHDL 檔案「都已加入專案」（至少）：
   - `fft_system_top.vhd`
   - `rs232_link.vhd`
   - `rs232_t1.vhd`（`rs232_link` 內部會用到 `RS232_T1`）
   - `rs232_r2.vhd`（`rs232_link` 內部會用到 `RS232_R2`）
   - `fft_core_stub.vhd`
3. 重新 Compile。

---

## 2) Error (10430): `fft_system_top` 已存在於 `work`

### 錯誤訊息

> Error (10430): VHDL Primary Unit Declaration error … primary unit "fft_system_top" already exists in library "work"

### 原因

專案同時加入了兩個（或以上）檔案，且它們都宣告了：

```vhdl
entity fft_system_top is
```

常見情境：
- 新專案加入了 `Vhdl1.vhd`（裡面也是 `fft_system_top`）
- 同時又加入另一份 `fft_system_top.vhd`

### 解法

- **專案中只能保留一個** `entity fft_system_top`。
- 到 **Project → Add/Remove Files in Project…**：
  - 移除其中一份 top 檔案，或
  - 保留兩份但把其中一份的 `entity` 改名（且 architecture 名稱也要對應修改）。

---

## 3) Error (10309): `out` 介面不能被讀取（`tx_ready`）

### 錯誤訊息

> Error (10309): VHDL Interface Declaration error … interface object "tx_ready" of mode out cannot be read. Change object mode to buffer.

### 原因

在 VHDL-93/2002 規範下，`out` port 不能在 entity 內部直接讀取。例如：

```vhdl
if (tx_valid = '1') and (tx_ready = '1') then
```

### 解法（建議做法：不要用 buffer）

新增內部訊號，例如 `tx_ready_i`：

- 用 `tx_ready_i` 做判斷
- 再把 `tx_ready <= tx_ready_i;` 輸出

（此專案已在 `rs232_link.vhd` 套用此修正。）

---

## 4) `quartus_map.exe` Access Violation（Elaborate/Map 階段當機）

### 現象

編譯到 Analysis & Synthesis（`quartus_map`）時直接跳出：

> *** Fatal Error: Access Violation … Module: quartus_map.exe

Stack trace 常見會出現：
- `VRFX_ELABORATOR::elaborate`

### 可能原因 A：專案檔案清單不乾淨（遺失檔案/幽靈檔）

曾出現：

- `Warning (12019): Can't analyze file -- file Vhdl1.vhd is missing`
- `Warning (12125): Using design file fft_system_top.vhd, which is not specified as a design file for the current project`

這代表 `.qsf` 仍引用了不存在的檔案，或真正要用的檔案未正式加入 project。

#### 解法

1. 在 Quartus：**Project → Add/Remove Files in Project…**
2. 移除所有「不存在」的檔案引用（例如 `Vhdl1.vhd`）
3. 確認 top 檔案有正確加入專案
4. 在 **Assignments → Settings → General**
   - 明確設定 **Top-level entity = `fft_system_top`**
5. **Project → Clean Project Files**（必要時手動刪除 `db/`, `incremental_db/`, `output_files/`）

### 可能原因 B：Quartus 13.1 對部分 VHDL 寫法不穩（Elaboration bug）

Quartus 13.1 很舊，某些看似合法的寫法可能在 elaboration 階段導致工具崩潰。

本次為提高穩定性，已做以下相容性處理：

1. **避免 VHDL-2008 風格的結尾**
   - 例如把 `end entity;` / `end architecture;` 改成 `end <name>;` / `end rtl;`

2. **避免「轉型後再切片」的表達式**
   - 例如把 `std_logic_vector(x)(7 downto 0)` 改成 `std_logic_vector(x(7 downto 0))`

3. **避免不定長回傳型別**
   - 例如 `function ... return signed` 改成固定 subtype：
     - `subtype s16_t is signed(15 downto 0);`

4. **避免 generic 用在 array/range bounds（穩定性 workaround）**
   - `FFT_SIZE` / `DATA_WIDTH` 保留在 entity 介面
   - 但內部 memory、index、width bounds 改用固定常數（本專案目標固定 256/16）

> 最後確認：上述調整後可成功完成編譯。

---

## 5) 小提醒：警告訊息

### Warning (10036): `len1` assigned but never read

這是「變數/訊號有被賦值但後續沒有使用」的警告，不會阻止編譯。
若要消除：
- 確認是否真的需要 `len1`
- 或在長度檢查、回傳封包長度等處把 `len1` 用起來

---

## 建議的排錯順序（快速）

1. 先確定 **Top-level entity 唯一且正確**（避免 10430）
2. 確定專案 **所有用到的 VHDL 檔都加入**（避免 10481）
3. 避免在 entity 內讀取 `out` port（避免 10309）
4. 若 `quartus_map.exe` 崩潰：
   - 先清掉幽靈檔/遺失檔引用 + Clean project
   - 再考慮 VHDL 相容性 workaround（本專案已套用）

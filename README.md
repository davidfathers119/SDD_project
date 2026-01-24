# SDD FFT 專案

FPGA-based FFT 訊號處理系統，整合 Visual Basic 介面與 RS-232 通訊

## 專案說明

本專案實作一個完整的 FFT (Fast Fourier Transform) 訊號處理系統，使用 FPGA 進行硬體加速運算，並透過 RS-232 串列通訊與 Visual Basic 介面整合。

## 專案結構

- `template.vhd` - VHDL 程式模板
- `FFT/` - FFT 專案資料夾
  - `README.md` - 功能說明文件
  - `spec.md` - 技術規格文件

## 主要功能

1. **VB 波形輸入與顯示** - 產生或匯入時域訊號並顯示波形
2. **RS-232 資料傳輸** - VB 透過串列埠傳送資料至 FPGA
3. **FPGA FFT 運算** - 硬體加速執行快速傅立葉轉換
4. **頻譜顯示與分析** - 接收 FFT 結果並繪製頻域頻譜

## 技術規格

- FFT 點數：64/128/256/512/1024（可配置）
- 資料位元寬度：16-bit
- 通訊介面：RS-232 (115200 bps)
- 演算法：Radix-2 DIT FFT

## 開發環境

- **硬體開發**：VHDL (Xilinx Vivado / Intel Quartus)
- **軟體開發**：Visual Basic
- **通訊協定**：RS-232

## 文件

詳細文件請參考：
- [功能說明](FFT/README.md)
- [技術規格](FFT/spec.md)

## 授權

（待定義）

---

**最後更新**：2026-01-25

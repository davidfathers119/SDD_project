# Visual Basic .NET 開發建議

## 推薦版本與配置

### 開發環境
- **IDE**: Visual Studio 2022 Community Edition (免費)
- **.NET 版本**: .NET 6.0 或 .NET 7.0
- **專案類型**: Windows Forms App (.NET)

### 為什麼選擇 .NET 6.0/7.0？

#### 優勢
1. **長期支援 (LTS)**: .NET 6.0 有 3 年 LTS，穩定可靠
2. **效能提升**: 相比舊版 .NET Framework 有顯著效能改善
3. **跨平台**: 雖然本專案針對 Windows，但保有未來擴展性
4. **現代化語言特性**: 支援最新的 C# 和 VB.NET 語法
5. **活躍社群**: 持續更新和豐富的第三方套件支援

#### .NET 版本比較

| 版本 | 發布年 | 支援至 | 推薦度 | 備註 |
|------|--------|--------|--------|------|
| .NET 6.0 | 2021 | 2024/11 | ⭐⭐⭐⭐⭐ | LTS，最穩定 |
| .NET 7.0 | 2022 | 2024/05 | ⭐⭐⭐⭐ | 新功能，短期支援 |
| .NET 8.0 | 2023 | 2026/11 | ⭐⭐⭐⭐⭐ | 最新 LTS（若可用） |
| .NET Framework 4.8 | 2019 | 持續 | ⭐⭐⭐ | 舊版，但相容性佳 |

### 推薦使用 .NET 6.0 的原因
- ✅ LTS 版本，生產環境穩定
- ✅ 串列埠支援完善 (System.IO.Ports)
- ✅ Windows Forms 支援良好
- ✅ NuGet 套件相容性最佳
- ✅ 學習資源豐富

---

## 必要的 NuGet 套件

### 1. 串列埠通訊
```
System.IO.Ports
版本: 7.0.0 或更高
用途: RS-232 串列埠控制
```

### 2. 圖表繪製（三選一）

#### 選項 A: ScottPlot (推薦) ⭐⭐⭐⭐⭐
```
ScottPlot.WinForms
版本: 4.1.x 或 5.0.x
優點:
  - 極高效能，適合即時資料
  - 簡單易用的 API
  - 支援大量資料點
  - 豐富的圖表類型
  - 免費開源
```

#### 選項 B: OxyPlot ⭐⭐⭐⭐
```
OxyPlot.WindowsForms
版本: 2.1.x
優點:
  - 成熟穩定
  - 跨平台支援
  - 美觀的預設樣式
```

#### 選項 C: LiveCharts ⭐⭐⭐
```
LiveCharts.WinForms
版本: 0.9.x
優點:
  - 動畫效果佳
  - 適合儀表板風格
```

### 3. 數學運算（可選）
```
MathNet.Numerics
版本: 5.0.0 或更高
用途: 複數運算、FFT 驗證
```

---

## 專案結構建議

```
VB_FFT_Interface/
│
├── VB_FFT_Interface.sln          # 解決方案檔
├── VB_FFT_Interface.vbproj       # 專案檔
│
├── Forms/                         # 表單
│   ├── MainForm.vb                # 主介面
│   └── SettingsForm.vb            # 設定對話框
│
├── Modules/                       # 功能模組
│   ├── RS232Module.vb             # 串列埠通訊
│   ├── PlotModule.vb              # 圖表繪製
│   ├── WaveGenerator.vb           # 波形產生
│   └── DataProcessor.vb           # 資料處理
│
├── Models/                        # 資料模型
│   ├── SignalData.vb              # 訊號資料類別
│   └── FFTResult.vb               # FFT 結果類別
│
├── Utils/                         # 工具類別
│   ├── PacketBuilder.vb           # 封包建構
│   └── Checksum.vb                # 檢查碼計算
│
└── Resources/                     # 資源檔
    ├── Icons/
    └── Config/
```

---

## 關鍵程式碼建議

### 1. 串列埠初始化 (.NET 6.0)

```vb
Imports System.IO.Ports

Public Class RS232Module
    Private WithEvents serialPort As SerialPort
    
    Public Sub OpenPort(portName As String)
        serialPort = New SerialPort() With {
            .PortName = portName,
            .BaudRate = 115200,
            .DataBits = 8,
            .Parity = Parity.None,
            .StopBits = StopBits.One,
            .Handshake = Handshake.None,
            .ReadTimeout = 5000,
            .WriteTimeout = 5000
        }
        
        Try
            serialPort.Open()
            Debug.WriteLine($"串列埠 {portName} 開啟成功")
        Catch ex As Exception
            MessageBox.Show($"開啟串列埠失敗: {ex.Message}")
        End Try
    End Sub
    
    Public Sub SendData(data As Byte())
        If serialPort?.IsOpen Then
            serialPort.Write(data, 0, data.Length)
        End If
    End Sub
    
    Private Sub SerialPort_DataReceived(sender As Object, e As SerialDataReceivedEventArgs) _
        Handles serialPort.DataReceived
        ' 非同步接收資料
        Dim bytesToRead = serialPort.BytesToRead
        Dim buffer(bytesToRead - 1) As Byte
        serialPort.Read(buffer, 0, bytesToRead)
        ' 處理接收的資料...
    End Sub
End Class
```

### 2. ScottPlot 繪圖範例

```vb
Imports ScottPlot

Public Class PlotModule
    Private timePlot As FormsPlot
    Private freqPlot As FormsPlot
    
    Public Sub New(timePlotControl As FormsPlot, freqPlotControl As FormsPlot)
        timePlot = timePlotControl
        freqPlot = freqPlotControl
        InitializePlots()
    End Sub
    
    Private Sub InitializePlots()
        ' 時域圖表設定
        timePlot.Plot.Title("時域波形")
        timePlot.Plot.XLabel("樣本點")
        timePlot.Plot.YLabel("振幅")
        
        ' 頻域圖表設定
        freqPlot.Plot.Title("頻域頻譜")
        freqPlot.Plot.XLabel("頻率 (Hz)")
        freqPlot.Plot.YLabel("振幅")
    End Sub
    
    Public Sub PlotTimeDomain(data As Double())
        timePlot.Plot.Clear()
        timePlot.Plot.AddSignal(data)
        timePlot.Refresh()
    End Sub
    
    Public Sub PlotFrequencySpectrum(magnitude As Double(), frequencies As Double())
        freqPlot.Plot.Clear()
        freqPlot.Plot.AddScatter(frequencies, magnitude)
        freqPlot.Refresh()
    End Sub
End Class
```

### 3. 資料封包建構

```vb
Public Class PacketBuilder
    Private Const HEADER As UShort = &HAA55
    
    Public Shared Function BuildDataPacket(data As Short()) As Byte()
        Dim packet As New List(Of Byte)
        
        ' 標頭 (2 bytes)
        packet.AddRange(BitConverter.GetBytes(HEADER))
        
        ' 長度 (2 bytes)
        packet.AddRange(BitConverter.GetBytes(CUShort(data.Length)))
        
        ' 資料 (每個樣本 2 bytes 實部 + 2 bytes 虛部)
        For Each sample In data
            packet.AddRange(BitConverter.GetBytes(sample))  ' 實部
            packet.AddRange(BitConverter.GetBytes(CShort(0))) ' 虛部 (純實數訊號)
        Next
        
        ' 檢查碼 (2 bytes)
        Dim checksum = CalculateChecksum(packet.ToArray())
        packet.AddRange(BitConverter.GetBytes(checksum))
        
        Return packet.ToArray()
    End Function
    
    Private Shared Function CalculateChecksum(data As Byte()) As UShort
        Dim sum As Integer = 0
        For Each b In data
            sum = sum Xor b
        Next
        Return CUShort(sum And &HFFFF)
    End Function
End Class
```

---

## 效能優化建議

### 1. 使用 Task 進行非同步處理
```vb
Imports System.Threading.Tasks

Public Async Function SendAndReceiveAsync() As Task(Of Byte())
    ' 避免阻塞 UI 執行緒
    Return Await Task.Run(Function()
        ' 執行耗時操作
        Return receivedData
    End Function)
End Function
```

### 2. 使用 Buffer 降低記憶體配置
```vb
' 重複使用緩衝區
Private receiveBuffer(4096) As Byte
```

### 3. 圖表更新頻率控制
```vb
Private lastUpdateTime As DateTime = DateTime.Now

Public Sub UpdatePlot(data As Double())
    ' 限制更新頻率為每 50ms
    If (DateTime.Now - lastUpdateTime).TotalMilliseconds >= 50 Then
        PlotData(data)
        lastUpdateTime = DateTime.Now
    End If
End Sub
```

---

## 偵錯建議

### 1. 使用 Debug.WriteLine 追蹤
```vb
Debug.WriteLine($"發送資料: {BitConverter.ToString(data)}")
```

### 2. 例外處理
```vb
Try
    ' 串列埠操作
Catch ex As TimeoutException
    Debug.WriteLine("逾時錯誤")
Catch ex As UnauthorizedAccessException
    Debug.WriteLine("串列埠存取被拒")
Catch ex As Exception
    Debug.WriteLine($"未預期錯誤: {ex.Message}")
End Try
```

### 3. 使用中斷點與監看視窗
- 在資料接收處設定中斷點
- 監看 byte array 內容
- 使用 Immediate Window 測試運算式

---

## 系統需求

### 開發環境
- Windows 10/11 (64-bit)
- Visual Studio 2022 (17.0 或更高)
- .NET 6.0 SDK
- 至少 4GB RAM
- 10GB 可用硬碟空間

### 執行環境
- Windows 10/11
- .NET 6.0 Runtime (可隨應用程式發佈)
- 可用的 COM 埠
- 1GB RAM

---

## 發佈與部署

### 獨立部署 (Self-contained)
```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

優點：
- 不需目標機器安裝 .NET Runtime
- 單一執行檔，易於發佈

缺點：
- 檔案較大 (~80MB)

### 框架依賴部署 (Framework-dependent)
```bash
dotnet publish -c Release -r win-x64 --self-contained false
```

優點：
- 檔案較小 (~5MB)

缺點：
- 需安裝 .NET 6.0 Runtime

---

## 總結

**最佳選擇組合：**
- ✅ Visual Studio 2022
- ✅ .NET 6.0 (LTS)
- ✅ Windows Forms
- ✅ ScottPlot (繪圖)
- ✅ System.IO.Ports (串列埠)

此組合提供最佳的穩定性、效能和開發體驗！

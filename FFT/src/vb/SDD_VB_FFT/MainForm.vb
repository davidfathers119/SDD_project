Option Strict On
Option Explicit On

Imports System
Imports System.IO.Ports
Imports System.Threading
Imports System.Threading.Tasks
Imports System.Windows.Forms
Imports System.Windows.Forms.DataVisualization.Charting
Imports SDD_VB_FFT.Modules

Public Class MainForm
    Inherits Form

    Private Const N As Integer = 256

    Private ReadOnly _port As New SerialPortAdapter()
    Private ReadOnly _parser As New ByteStreamParser()
    Private ReadOnly _service As FftSessionService

    Private ReadOnly _cmbPorts As New ComboBox()
    Private ReadOnly _btnRefresh As New Button()
    Private ReadOnly _btnConnect As New Button()
    Private ReadOnly _btnSend As New Button()

    Private ReadOnly _txtFs As New TextBox()
    Private ReadOnly _txtFreq As New TextBox()
    Private ReadOnly _txtAmp As New TextBox()

    Private ReadOnly _lblStatus As New Label()

    Private ReadOnly _txtLog As New TextBox()
    Private _rxBytesTotal As Long
    Private _rxChunkCount As Integer
    Private _rxAllBytes As New System.Collections.Generic.List(Of Byte)()

    Private ReadOnly _chartTime As New Chart()
    Private ReadOnly _chartFreq As New Chart()
    Private ReadOnly _chartPhase As New Chart()

    Private _connected As Boolean

    Public Sub New()
        Text = "SDD FFT - VB.NET6 (Bring-up)"
        Width = 1400
        Height = 800

        _service = New FftSessionService(_port, _parser)

        AddHandler _port.PortError, Sub(msg)
                                        SetStatus($"Port error: {msg}")
                                        Log($"[PortError] {msg}")
                                    End Sub
        AddHandler _port.BytesReceived, Sub(data)
                                            If data Is Nothing Then Return
                                            Interlocked.Add(_rxBytesTotal, data.Length)
                                            Dim chunkIdx As Integer = Interlocked.Increment(_rxChunkCount)
                                            ' 收集所有資料
                                            SyncLock _rxAllBytes
                                                _rxAllBytes.AddRange(data)
                                            End SyncLock
                                            ' 顯示所有接收（用於診斷）
                                            Log($"[RX] chunk={data.Length} total={Interlocked.Read(_rxBytesTotal)} head={BitConverter.ToString(data, 0, Math.Min(8, data.Length))}")
                                        End Sub
        AddHandler _parser.ParserError, Sub(msg)
                                            SetStatus($"Parser error: {msg}")
                                            Log($"[ParserError] {msg}")
                                        End Sub
        AddHandler _parser.DebugTrace, Sub(msg)
                                           Log(msg)
                                       End Sub
        AddHandler _parser.PacketReceived, Sub(header, length, payload)
                                               Log($"[Packet] header=0x{header:X4} len={length} payloadBytes={If(payload Is Nothing, 0, payload.Length)}")
                                           End Sub

        InitializeUi()
        Log($"[App] BaseDir={AppDomain.CurrentDomain.BaseDirectory}")
        Log($"[App] Assembly={GetType(MainForm).Assembly.Location}")
        RefreshPorts()
    End Sub

    Private Sub InitializeUi()
        Dim topPanel As New FlowLayoutPanel() With {
            .Dock = DockStyle.Top,
            .Height = 48,
            .AutoSize = False
        }

        _btnRefresh.Text = "Refresh COM"
        AddHandler _btnRefresh.Click, Sub() RefreshPorts()

        _btnConnect.Text = "Connect"
        AddHandler _btnConnect.Click, Async Sub() Await ToggleConnectAsync()

        _btnSend.Text = "Send 256 pts"
        _btnSend.Enabled = False
        AddHandler _btnSend.Click, Async Sub() Await SendOnceAsync()

        _txtFs.Width = 80 : _txtFs.Text = "8000"
        _txtFreq.Width = 80 : _txtFreq.Text = "1000"
        _txtAmp.Width = 60 : _txtAmp.Text = "0.8"

        topPanel.Controls.Add(New Label() With {.Text = "COM:", .AutoSize = True, .Padding = New Padding(8, 12, 0, 0)})
        topPanel.Controls.Add(_cmbPorts)
        topPanel.Controls.Add(_btnRefresh)
        topPanel.Controls.Add(_btnConnect)
        topPanel.Controls.Add(New Label() With {.Text = "Fs(Hz):", .AutoSize = True, .Padding = New Padding(8, 12, 0, 0)})
        topPanel.Controls.Add(_txtFs)
        topPanel.Controls.Add(New Label() With {.Text = "Freq(Hz):", .AutoSize = True, .Padding = New Padding(8, 12, 0, 0)})
        topPanel.Controls.Add(_txtFreq)
        topPanel.Controls.Add(New Label() With {.Text = "Amp(0-1):", .AutoSize = True, .Padding = New Padding(8, 12, 0, 0)})
        topPanel.Controls.Add(_txtAmp)
        topPanel.Controls.Add(_btnSend)

        _lblStatus.Dock = DockStyle.Bottom
        _lblStatus.Height = 24
        _lblStatus.Text = "Ready"

        _txtLog.Dock = DockStyle.Bottom
        _txtLog.Height = 140
        _txtLog.Multiline = True
        _txtLog.ReadOnly = True
        _txtLog.ScrollBars = ScrollBars.Vertical
        _txtLog.Font = New Drawing.Font("Consolas", 9.0F)

        ' 主分割：左側時域，右側頻域
        Dim splitMain As New SplitContainer() With {
            .Dock = DockStyle.Fill,
            .Orientation = Orientation.Vertical,
            .SplitterDistance = CInt(Width * 0.4)
        }

        ' 右側分割：上方振幅，下方相位
        Dim splitFreq As New SplitContainer() With {
            .Dock = DockStyle.Fill,
            .Orientation = Orientation.Horizontal,
            .SplitterDistance = CInt(Height * 0.35)
        }

        SetupChart(_chartTime, "Time Domain", "Sample", "Amplitude")
        SetupChart(_chartFreq, "Frequency Domain (Magnitude)", "Bin", "|X|")
        SetupChart(_chartPhase, "Frequency Domain (Phase)", "Bin", "Phase (deg)")

        splitMain.Panel1.Controls.Add(_chartTime)
        splitFreq.Panel1.Controls.Add(_chartFreq)
        splitFreq.Panel2.Controls.Add(_chartPhase)
        splitMain.Panel2.Controls.Add(splitFreq)

        Controls.Add(splitMain)
        Controls.Add(topPanel)
        Controls.Add(_txtLog)
        Controls.Add(_lblStatus)
    End Sub

    Private Sub SetupChart(chart As Chart, title As String, xlabel As String, ylabel As String)
        chart.Dock = DockStyle.Fill
        chart.ChartAreas.Clear()
        chart.Series.Clear()

        Dim area As New ChartArea("A")
        area.AxisX.Title = xlabel
        area.AxisY.Title = ylabel
        
        ' 設定Y軸自動縮放
        area.AxisY.IsStartedFromZero = False
        
        chart.ChartAreas.Add(area)

        Dim s As New Series("S")
        s.ChartType = SeriesChartType.FastLine
        s.BorderWidth = 2
        chart.Series.Add(s)

        chart.Titles.Clear()
        chart.Titles.Add(title)
    End Sub

    Private Sub RefreshPorts()
        _cmbPorts.Items.Clear()
        For Each p In SerialPort.GetPortNames()
            _cmbPorts.Items.Add(p)
        Next
        If _cmbPorts.Items.Count > 0 Then _cmbPorts.SelectedIndex = 0
    End Sub

    Private Async Function ToggleConnectAsync() As Task
        If _connected Then
            _port.Close()
            _connected = False
            _btnConnect.Text = "Connect"
            _btnSend.Enabled = False
            SetStatus("Disconnected")
            Return
        End If

        If _cmbPorts.SelectedItem Is Nothing Then
            SetStatus("請先選擇 COM 埠")
            Return
        End If

        Try
            Dim portName As String = _cmbPorts.SelectedItem.ToString()
            _port.Open(portName, 38400)
            _connected = True
            _btnConnect.Text = "Disconnect"
            _btnSend.Enabled = True
            SetStatus($"Connected: {portName} @38400")
        Catch ex As Exception
            SetStatus($"Connect failed: {ex.Message}")
        End Try

        Await Task.CompletedTask
    End Function

    Private Async Function SendOnceAsync() As Task
        If Not _connected Then
            SetStatus("尚未連線")
            Return
        End If

        Dim fsHz As Double
        Dim freqHz As Double
        Dim amp As Double

        If Not Double.TryParse(_txtFs.Text, fsHz) Then
            SetStatus("Fs 不是有效數字")
            Return
        End If
        If Not Double.TryParse(_txtFreq.Text, freqHz) Then
            SetStatus("Freq 不是有效數字")
            Return
        End If
        If Not Double.TryParse(_txtAmp.Text, amp) Then
            SetStatus("Amp 不是有效數字")
            Return
        End If

        Dim re As Short() = WaveGenerator.GenerateSine(N, fsHz, freqHz, amp)
        Dim im As Short() = New Short(N - 1) {}

        PlotTime(re)

        Dim packet As Byte() = Rs232PacketCodec.BuildTimeDomainPacket(re, im)

        Using cts As New CancellationTokenSource()
            Try
                _btnSend.Enabled = False
                _rxChunkCount = 0
                Interlocked.Exchange(_rxBytesTotal, 0)
                SyncLock _rxAllBytes
                    _rxAllBytes.Clear()
                End SyncLock
                
                ' 積極清理策略：重複清理直到穩定
                Log("[Cleanup] 開始清理 FPGA 緩衝區...")
                Dim cleanupRounds As Integer = 0
                Dim maxRounds As Integer = 10
                
                While cleanupRounds < maxRounds
                    _port.ClearBuffers()
                    Await Task.Delay(500)  ' 等待 500ms
                    
                    ' 檢查是否有新資料
                    Dim bytesRead As Integer = _port.BytesToRead
                    If bytesRead > 0 Then
                        Dim garbage(bytesRead - 1) As Byte
                        Dim actualRead As Integer = _port.Read(garbage, 0, bytesRead)
                        Log($"[Cleanup] Round {cleanupRounds + 1}: 丟棄 {actualRead} bytes")
                        cleanupRounds += 1
                    Else
                        ' 連續兩輪都沒有資料，認為已經清理乾淨
                        If cleanupRounds > 0 Then
                            Exit While
                        End If
                        cleanupRounds += 1
                    End If
                End While
                
                ' 最後清理通過事件接收的資料
                SyncLock _rxAllBytes
                    If _rxAllBytes.Count > 0 Then
                        Log($"[Cleanup] 清除事件緩衝區 {_rxAllBytes.Count} bytes")
                        _rxAllBytes.Clear()
                    End If
                End SyncLock
                _rxChunkCount = 0
                Interlocked.Exchange(_rxBytesTotal, 0)
                
                Log("[Cleanup] 清理完成，開始發送封包")
                
                Dim previewLen As Integer = Math.Min(8, packet.Length)
                Dim preview As String = BitConverter.ToString(packet, 0, previewLen)
                SetStatus($"Sending... TX[{previewLen}]={preview} waiting response")
                Log($"[TX] bytes={packet.Length} head={preview}")

                Dim response = Await _service.SendAndReceiveAsync(packet, timeoutMs:=15000, ct:=cts.Token)
                Dim outRe = response.Item1
                Dim outIm = response.Item2

                Dim mag As Double() = SpectrumMath.Magnitude(outRe, outIm)
                Dim phase As Double() = SpectrumMath.Phase(outRe, outIm)
                PlotFreq(mag)
                PlotPhase(phase)

                SetStatus("Done")
            Catch ex As TimeoutException
                ' Dump所有收到的資料
                Dim allData As Byte()
                SyncLock _rxAllBytes
                    allData = _rxAllBytes.ToArray()
                End SyncLock
                If allData.Length > 0 Then
                    Dim dumpStr As String = BitConverter.ToString(allData)
                    Log($"[RX Dump] Total {allData.Length} bytes:")
                    ' 分段顯示，每行32個byte
                    Dim lineSize As Integer = 96 ' 32 bytes * 3 chars per byte
                    For i As Integer = 0 To dumpStr.Length - 1 Step lineSize
                        Dim len As Integer = Math.Min(lineSize, dumpStr.Length - i)
                        Log($"  {dumpStr.Substring(i, len)}")
                    Next
                End If
                SetStatus($"Timeout: {ex.Message}")
                Log($"[Error] {ex.Message}")
            Catch ex As Exception
                SetStatus($"Error: {ex.Message}")
                Log($"[Error] {ex}")
            Finally
                _btnSend.Enabled = True
            End Try
        End Using
    End Function

    Private Sub Log(message As String)
        If InvokeRequired Then
            BeginInvoke(New Action(Of String)(AddressOf Log), message)
            Return
        End If

        If _txtLog.TextLength > 20000 Then
            _txtLog.Clear()
        End If

        _txtLog.AppendText($"{DateTime.Now:HH:mm:ss.fff} {message}{Environment.NewLine}")
    End Sub

    Private Sub PlotTime(re As Short())
        Dim s = _chartTime.Series(0)
        s.Points.Clear()
        For i As Integer = 0 To re.Length - 1
            s.Points.AddXY(i, re(i))
        Next
    End Sub

    Private Sub PlotFreq(mag As Double())
        Dim s = _chartFreq.Series(0)
        s.Points.Clear()
        ' 先畫前 N/2（常用）
        Dim half As Integer = mag.Length \ 2
        For i As Integer = 0 To half - 1
            s.Points.AddXY(i, mag(i))
        Next
    End Sub

    Private Sub PlotPhase(phase As Double())
        Dim s = _chartPhase.Series(0)
        s.Points.Clear()
        Dim half As Integer = phase.Length \ 2
        For i As Integer = 0 To half - 1
            s.Points.AddXY(i, phase(i))
        Next
    End Sub

    Private Sub SetStatus(textValue As String)
        If InvokeRequired Then
            BeginInvoke(New Action(Of String)(AddressOf SetStatus), textValue)
            Return
        End If
        _lblStatus.Text = textValue
    End Sub
End Class

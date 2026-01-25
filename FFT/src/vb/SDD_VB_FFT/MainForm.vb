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

    Private ReadOnly _chartTime As New Chart()
    Private ReadOnly _chartFreq As New Chart()

    Private _connected As Boolean

    Public Sub New()
        Text = "SDD FFT - VB.NET6 (Bring-up)"
        Width = 1200
        Height = 720

        _service = New FftSessionService(_port, _parser)

        AddHandler _port.PortError, Sub(msg) SetStatus($"Port error: {msg}")
        AddHandler _parser.ParserError, Sub(msg) SetStatus($"Parser error: {msg}")

        InitializeUi()
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

        Dim split As New SplitContainer() With {
            .Dock = DockStyle.Fill,
            .Orientation = Orientation.Vertical,
            .SplitterDistance = CInt(Width / 2)
        }

        SetupChart(_chartTime, "Time Domain", "Sample", "Amplitude")
        SetupChart(_chartFreq, "Frequency Domain (Magnitude)", "Bin", "|X|")

        split.Panel1.Controls.Add(_chartTime)
        split.Panel2.Controls.Add(_chartFreq)

        Controls.Add(split)
        Controls.Add(topPanel)
        Controls.Add(_lblStatus)
    End Sub

    Private Sub SetupChart(chart As Chart, title As String, xlabel As String, ylabel As String)
        chart.Dock = DockStyle.Fill
        chart.ChartAreas.Clear()
        chart.Series.Clear()

        Dim area As New ChartArea("A")
        area.AxisX.Title = xlabel
        area.AxisY.Title = ylabel
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
                SetStatus("Sending... waiting response")

                Dim response = Await _service.SendAndReceiveAsync(packet, timeoutMs:=8000, ct:=cts.Token)
                Dim outRe = response.Item1
                Dim outIm = response.Item2

                Dim mag As Double() = SpectrumMath.Magnitude(outRe, outIm)
                PlotFreq(mag)

                SetStatus("Done")
            Catch ex As Exception
                SetStatus($"Error: {ex.Message}")
            Finally
                _btnSend.Enabled = True
            End Try
        End Using
    End Function

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

    Private Sub SetStatus(textValue As String)
        If InvokeRequired Then
            BeginInvoke(New Action(Of String)(AddressOf SetStatus), textValue)
            Return
        End If
        _lblStatus.Text = textValue
    End Sub
End Class

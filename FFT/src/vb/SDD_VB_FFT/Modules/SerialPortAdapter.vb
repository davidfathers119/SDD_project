Option Strict On
Option Explicit On

Imports System
Imports System.IO.Ports
Imports System.Threading
Imports System.Threading.Tasks

Namespace Modules
    Public Class SerialPortAdapter
        Implements IDisposable

        Public Event BytesReceived(data As Byte())
        Public Event PortError(message As String)

        Private ReadOnly _port As SerialPort

        Public Sub New()
            _port = New SerialPort() With {
                .BaudRate = 38400,
                .DataBits = 8,
                .Parity = Parity.None,
                .StopBits = StopBits.One,
                .Handshake = Handshake.None,
                .DtrEnable = True,
                .RtsEnable = True,
                .ReadTimeout = 2000,
                .WriteTimeout = 2000
            }
            AddHandler _port.DataReceived, AddressOf OnDataReceived
        End Sub

        Public Sub ClearBuffers()
            If Not _port.IsOpen Then Return
            Try
                _port.DiscardInBuffer()
                _port.DiscardOutBuffer()
            Catch ex As Exception
                RaiseEvent PortError($"ClearBuffers failed: {ex.Message}")
            End Try
        End Sub

        Public ReadOnly Property IsOpen As Boolean
            Get
                Return _port.IsOpen
            End Get
        End Property

        Public ReadOnly Property BytesToRead As Integer
            Get
                If Not _port.IsOpen Then Return 0
                Try
                    Return _port.BytesToRead
                Catch
                    Return 0
                End Try
            End Get
        End Property

        Public Function Read(buffer As Byte(), offset As Integer, count As Integer) As Integer
            If Not _port.IsOpen Then Return 0
            Try
                Return _port.Read(buffer, offset, count)
            Catch ex As Exception
                RaiseEvent PortError($"Read failed: {ex.Message}")
                Return 0
            End Try
        End Function

        Public Sub Open(portName As String, baudRate As Integer)
            Try
                If _port.IsOpen Then _port.Close()
                _port.PortName = portName
                _port.BaudRate = baudRate
                _port.Open()
            Catch ex As Exception
                RaiseEvent PortError(ex.Message)
                Throw
            End Try
        End Sub

        Public Sub Close()
            Try
                If _port.IsOpen Then _port.Close()
            Catch ex As Exception
                RaiseEvent PortError(ex.Message)
            End Try
        End Sub

        Public Async Function WriteAsync(data As Byte(), ct As CancellationToken) As Task
            If data Is Nothing Then Throw New ArgumentNullException(NameOf(data))
            If Not _port.IsOpen Then Throw New InvalidOperationException("SerialPort 尚未開啟")

            Await Task.Run(Sub()
                               ct.ThrowIfCancellationRequested()
                               _port.Write(data, 0, data.Length)
                           End Sub, ct)
        End Function

        Private Sub OnDataReceived(sender As Object, e As SerialDataReceivedEventArgs)
            Try
                Dim count As Integer = _port.BytesToRead
                If count <= 0 Then Return

                Dim buf(count - 1) As Byte
                Dim read As Integer = _port.Read(buf, 0, count)
                If read <= 0 Then Return

                If read <> buf.Length Then
                    Dim trimmed(read - 1) As Byte
                    Array.Copy(buf, trimmed, read)
                    RaiseEvent BytesReceived(trimmed)
                Else
                    RaiseEvent BytesReceived(buf)
                End If
            Catch ex As Exception
                RaiseEvent PortError(ex.Message)
            End Try
        End Sub

        Public Sub Dispose() Implements IDisposable.Dispose
            Try
                Close()
            Finally
                RemoveHandler _port.DataReceived, AddressOf OnDataReceived
                _port.Dispose()
            End Try
        End Sub
    End Class
End Namespace

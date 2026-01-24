Option Strict On
Option Explicit On

Imports System
Imports System.Threading
Imports System.Threading.Tasks

Namespace Modules
    Public Class FftSessionService
        Private ReadOnly _port As SerialPortAdapter
        Private ReadOnly _parser As ByteStreamParser

        Private _pending As TaskCompletionSource(Of (UShort, UShort, Byte()))

        Public Sub New(port As SerialPortAdapter, parser As ByteStreamParser)
            _port = port
            _parser = parser

            AddHandler _port.BytesReceived, AddressOf OnBytes
            AddHandler _parser.PacketReceived, AddressOf OnPacket
        End Sub

        Private Sub OnBytes(data As Byte())
            _parser.Feed(data)
        End Sub

        Private Sub OnPacket(header As UShort, length As UShort, payload As Byte())
            Dim tcs = _pending
            If tcs Is Nothing Then Return

            ' 目前 bring-up：只接受 0x55AA 回包
            If header <> Rs232PacketCodec.HeaderRxFromFpga Then Return

            _pending = Nothing
            tcs.TrySetResult((header, length, payload))
        End Sub

        Public Async Function SendAndReceiveAsync(timePacket As Byte(), timeoutMs As Integer, ct As CancellationToken) As Task(Of (Short(), Short()))
            If timeoutMs <= 0 Then Throw New ArgumentOutOfRangeException(NameOf(timeoutMs))

            Dim tcs As New TaskCompletionSource(Of (UShort, UShort, Byte()))(TaskCreationOptions.RunContinuationsAsynchronously)
            _pending = tcs

            Await _port.WriteAsync(timePacket, ct)

            Using cts As CancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(ct)
                cts.CancelAfter(timeoutMs)

                Dim completed = Await Task.WhenAny(tcs.Task, Task.Delay(Timeout.Infinite, cts.Token))
                If completed IsNot tcs.Task Then
                    _pending = Nothing
                    Throw New TimeoutException("等待 FPGA 回包逾時")
                End If

                Dim (_, length, payload) = Await tcs.Task
                Dim n As Integer = CInt(length)
                Dim re As Short() = Nothing
                Dim im As Short() = Nothing
                Rs232PacketCodec.ParseComplexPayload(payload, n, re, im)
                Return (re, im)
            End Using
        End Function
    End Class
End Namespace

Option Strict On
Option Explicit On

Imports System

Namespace Modules
    Public Class ByteStreamParser
        Public Event PacketReceived(header As UShort, length As UShort, payload As Byte())
        Public Event ParserError(reason As String)
        Public Event DebugTrace(message As String)

        Private Enum State
            WaitH1
            WaitH2
            WaitLen0
            WaitLen1
            WaitPayload
        End Enum

        Private _state As State = State.WaitH1
        Private _h1 As Byte
        Private _h2 As Byte
        Private _len0 As Byte
        Private _len1 As Byte
        Private _expectedPayloadBytes As Integer
        Private _payload As Byte()
        Private _payloadOffset As Integer

        Public Sub Reset()
            _state = State.WaitH1
            _expectedPayloadBytes = 0
            _payload = Array.Empty(Of Byte)()
            _payloadOffset = 0
        End Sub

        Public Sub Feed(data As Byte())
            If data Is Nothing OrElse data.Length = 0 Then Return
            For Each b As Byte In data
                FeedByte(b)
            Next
        End Sub

        Private Sub FeedByte(b As Byte)
            Select Case _state
                Case State.WaitH1
                    If b = &HAA OrElse b = &H55 Then
                        _h1 = b
                        _state = State.WaitH2
                        RaiseEvent DebugTrace($"[Parser] Found H1=0x{b:X2}, waiting H2")
                    End If

                Case State.WaitH2
                    _h2 = b
                    If (_h1 = &HAA AndAlso _h2 = &H55) OrElse (_h1 = &H55 AndAlso _h2 = &HAA) Then
                        _state = State.WaitLen0
                        RaiseEvent DebugTrace($"[Parser] Header matched: 0x{_h1:X2}{_h2:X2}, waiting length")
                    Else
                        RaiseEvent DebugTrace($"[Parser] Header mismatch: 0x{_h1:X2}{_h2:X2}, reset")
                        _state = State.WaitH1
                    End If

                Case State.WaitLen0
                    _len0 = b
                    _state = State.WaitLen1

                Case State.WaitLen1
                    _len1 = b
                    Dim length As UShort = CUShort(CUShort(_len0) Or (CUShort(_len1) << 8))
                    _expectedPayloadBytes = CInt(length) * 4

                    If _expectedPayloadBytes < 0 OrElse _expectedPayloadBytes > 1024 * 4 Then
                        RaiseEvent ParserError($"Bad length: {length}")
                        Reset()
                        Return
                    End If

                    RaiseEvent DebugTrace($"[Parser] Length={length}, expecting {_expectedPayloadBytes} bytes")
                    _payload = New Byte(_expectedPayloadBytes - 1) {}
                    _payloadOffset = 0
                    _state = State.WaitPayload

                Case State.WaitPayload
                    If _payloadOffset < _payload.Length Then
                        _payload(_payloadOffset) = b
                        _payloadOffset += 1
                    End If

                    If _payloadOffset >= _payload.Length Then
                        Dim header As UShort = CUShort(CUShort(_h1) << 8 Or CUShort(_h2))
                        Dim length As UShort = CUShort(CUShort(_len0) Or (CUShort(_len1) << 8))
                        RaiseEvent PacketReceived(header, length, _payload)
                        Reset()
                    End If
            End Select
        End Sub
    End Class
End Namespace

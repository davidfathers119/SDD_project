Option Strict On
Option Explicit On

Imports System

Namespace Modules
    Public NotInheritable Class Rs232PacketCodec
        Private Sub New()
        End Sub

        Public Const HeaderTxToFpga As UShort = &HAA55US
        Public Const HeaderRxFromFpga As UShort = &H55AAUS

        Public Shared Function BuildTimeDomainPacket(samplesRe As Short(), samplesIm As Short()) As Byte()
            If samplesRe Is Nothing Then Throw New ArgumentNullException(NameOf(samplesRe))
            If samplesIm Is Nothing Then Throw New ArgumentNullException(NameOf(samplesIm))
            If samplesRe.Length <> samplesIm.Length Then Throw New ArgumentException("Re/Im 長度必須相同")

            Dim n As Integer = samplesRe.Length
            Dim payloadBytes As Integer = n * 4
            Dim total As Integer = 2 + 2 + payloadBytes
            Dim buffer(total - 1) As Byte

            Dim offset As Integer = 0
            ' FPGA expects RX header bytes in-order: 0xAA then 0x55.
            buffer(offset) = CByte((HeaderTxToFpga >> 8) And &HFFUS)
            buffer(offset + 1) = CByte(HeaderTxToFpga And &HFFUS)
            offset += 2
            WriteUInt16LE(buffer, offset, CUShort(n)) : offset += 2

            For i As Integer = 0 To n - 1
                WriteInt16LE(buffer, offset, samplesRe(i)) : offset += 2
                WriteInt16LE(buffer, offset, samplesIm(i)) : offset += 2
            Next

            Return buffer
        End Function

        Public Shared Sub ParseComplexPayload(payload As Byte(), n As Integer, ByRef outRe As Short(), ByRef outIm As Short())
            If payload Is Nothing Then Throw New ArgumentNullException(NameOf(payload))
            If payload.Length <> n * 4 Then Throw New ArgumentException("payload 長度不符合 N*4")

            Dim reArr(n - 1) As Short
            Dim imArr(n - 1) As Short

            Dim offset As Integer = 0
            For i As Integer = 0 To n - 1
                reArr(i) = ReadInt16LE(payload, offset) : offset += 2
                imArr(i) = ReadInt16LE(payload, offset) : offset += 2
            Next

            outRe = reArr
            outIm = imArr
        End Sub

        Public Shared Sub WriteUInt16LE(dst As Byte(), offset As Integer, value As UShort)
            dst(offset) = CByte(value And &HFFUS)
            dst(offset + 1) = CByte((value >> 8) And &HFFUS)
        End Sub

        Public Shared Sub WriteInt16LE(dst As Byte(), offset As Integer, value As Short)
            ' Avoid OverflowException for negative values when converting Short -> UShort.
            Dim u As UShort = CUShort(CInt(value) And &HFFFF)
            WriteUInt16LE(dst, offset, u)
        End Sub

        Public Shared Function ReadUInt16LE(src As Byte(), offset As Integer) As UShort
            Return CUShort(CUShort(src(offset)) Or (CUShort(src(offset + 1)) << 8))
        End Function

        Public Shared Function ReadInt16LE(src As Byte(), offset As Integer) As Short
            Dim u As UShort = ReadUInt16LE(src, offset)
            Return CType(u, Short)
        End Function
    End Class
End Namespace

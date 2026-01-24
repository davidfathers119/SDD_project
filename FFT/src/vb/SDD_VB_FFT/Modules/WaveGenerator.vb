Option Strict On
Option Explicit On

Imports System

Namespace Modules
    Public NotInheritable Class WaveGenerator
        Private Sub New()
        End Sub

        Public Shared Function GenerateSine(n As Integer, fsHz As Double, freqHz As Double, amplitude01 As Double) As Short()
            If n <= 0 Then Throw New ArgumentOutOfRangeException(NameOf(n))
            If fsHz <= 0 Then Throw New ArgumentOutOfRangeException(NameOf(fsHz))
            If amplitude01 < 0 OrElse amplitude01 > 1 Then Throw New ArgumentOutOfRangeException(NameOf(amplitude01))

            Dim result(n - 1) As Short
            Dim scale As Double = amplitude01 * 32767.0

            For i As Integer = 0 To n - 1
                Dim t As Double = i / fsHz
                Dim v As Double = Math.Sin(2.0 * Math.PI * freqHz * t)
                Dim s As Integer = CInt(Math.Round(v * scale))
                If s > Short.MaxValue Then s = Short.MaxValue
                If s < Short.MinValue Then s = Short.MinValue
                result(i) = CShort(s)
            Next

            Return result
        End Function
    End Class
End Namespace

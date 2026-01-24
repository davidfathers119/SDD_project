Option Strict On
Option Explicit On

Imports System

Namespace Modules
    Public NotInheritable Class SpectrumMath
        Private Sub New()
        End Sub

        Public Shared Function Magnitude(re As Short(), im As Short()) As Double()
            If re Is Nothing Then Throw New ArgumentNullException(NameOf(re))
            If im Is Nothing Then Throw New ArgumentNullException(NameOf(im))
            If re.Length <> im.Length Then Throw New ArgumentException("Re/Im 長度必須相同")

            Dim n As Integer = re.Length
            Dim mag(n - 1) As Double

            For i As Integer = 0 To n - 1
                Dim r As Double = re(i)
                Dim j As Double = im(i)
                mag(i) = Math.Sqrt(r * r + j * j)
            Next

            Return mag
        End Function

        Public Shared Function FrequencyAxis(fsHz As Double, n As Integer) As Double()
            If fsHz <= 0 Then Throw New ArgumentOutOfRangeException(NameOf(fsHz))
            If n <= 0 Then Throw New ArgumentOutOfRangeException(NameOf(n))

            Dim f(n - 1) As Double
            For k As Integer = 0 To n - 1
                f(k) = (k * fsHz) / n
            Next
            Return f
        End Function
    End Class
End Namespace

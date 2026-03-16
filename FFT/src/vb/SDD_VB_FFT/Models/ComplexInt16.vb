Option Strict On
Option Explicit On

Namespace Models
    Public Structure ComplexInt16
        Public Property Re As Short
        Public Property Im As Short

        Public Sub New(reValue As Short, imValue As Short)
            Re = reValue
            Im = imValue
        End Sub
    End Structure
End Namespace

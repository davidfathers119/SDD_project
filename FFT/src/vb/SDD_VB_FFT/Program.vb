Imports System
Imports System.Windows.Forms

Friend Module Program
    <STAThread>
    Friend Sub Main()
        ApplicationConfiguration.Initialize()
        Application.Run(New MainForm())
    End Sub
End Module

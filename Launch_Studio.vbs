Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)

pythonwPath = "C:\Users\harsh\AppData\Local\Programs\Python\Python312\pythonw.exe"
scriptPath = currentDir & "\report_gui.py"

If fso.FileExists(pythonwPath) Then
    WshShell.Run """" & pythonwPath & """ """ & scriptPath & """", 0, False
Else
    WshShell.Run "pythonw """ & scriptPath & """", 0, False
End If

Set WshShell = Nothing
Set fso = Nothing

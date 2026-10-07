' FGO Q Battle Config Editor - Silent Launcher
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' 隔离 ADB 端口（默认 5038）
WshShell.Environment("PROCESS")("ANDROID_ADB_SERVER_PORT") = "5038"
WshShell.Environment("PROCESS")("ADB_SERVER_SOCKET") = "tcp:localhost:5038"

editorDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcherScript = editorDir & "\launcher.py"

pythonwPath = "C:\Program Files\Python310\pythonw.exe"
If Not fso.FileExists(pythonwPath) Then
    pythonwPath = "pythonw"
End If

WshShell.Run """" & pythonwPath & """ """ & launcherScript & """", 0, False


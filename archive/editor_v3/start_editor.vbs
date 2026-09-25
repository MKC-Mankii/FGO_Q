' FGO Q Battle Config Editor - Silent Launcher
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

editorDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcherScript = editorDir & "\launcher.py"

WshShell.Run "pythonw """ & launcherScript & """", 0, False

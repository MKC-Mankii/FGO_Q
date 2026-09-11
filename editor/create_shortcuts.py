import os
import sys
import subprocess

root_dir = r"F:\2nd Accra\Git\Github\FGO_Q"
launcher_script = os.path.join(root_dir, "editor", "launcher.py")
ico_path = os.path.join(root_dir, "editor", "icons", "fgo_editor.ico")

python_exe = sys.executable
pythonw_exe = python_exe
if python_exe.lower().endswith("python.exe"):
    cand = python_exe[:-10] + "pythonw.exe"
    if os.path.exists(cand):
        pythonw_exe = cand

shortcut_name = "FGO_Config_Editor.lnk"

vbs_script_content = f'''Set WshShell = CreateObject("WScript.Shell")
desktop = WshShell.SpecialFolders("Desktop")
rootDir = "{root_dir}"
target = "{pythonw_exe}"
args = """{launcher_script}"""
ico = "{ico_path}"

' 1. Local shortcut
Set lnk1 = WshShell.CreateShortcut(rootDir & "\\{shortcut_name}")
lnk1.TargetPath = target
lnk1.Arguments = args
lnk1.WorkingDirectory = rootDir
lnk1.IconLocation = ico & ",0"
lnk1.Description = "FGO Q Battle Config Editor"
lnk1.Save

' 2. Desktop shortcut
Set lnk2 = WshShell.CreateShortcut(desktop & "\\{shortcut_name}")
lnk2.TargetPath = target
lnk2.Arguments = args
lnk2.WorkingDirectory = rootDir
lnk2.IconLocation = ico & ",0"
lnk2.Description = "FGO Q Battle Config Editor"
lnk2.Save

WScript.Echo "Shortcuts successfully created!"
'''

temp_vbs = os.path.join(root_dir, "editor", "temp_create_lnk.vbs")
with open(temp_vbs, "w", encoding="utf-8") as f:
    f.write(vbs_script_content)

res = subprocess.run(["cscript", "//nologo", temp_vbs], capture_output=True, text=True)
print("STDOUT:", res.stdout.strip())
if res.stderr:
    print("STDERR:", res.stderr.strip())

if os.path.exists(temp_vbs):
    os.remove(temp_vbs)

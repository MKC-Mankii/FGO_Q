@echo off
set ANDROID_ADB_SERVER_PORT=5038
set ADB_SERVER_SOCKET=tcp:localhost:5038
pythonw "%~dp0launcher.py" --browser

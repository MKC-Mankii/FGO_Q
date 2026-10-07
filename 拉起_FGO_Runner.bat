@echo off
chcp 65001 >nul
title 就绪 FGO 运行环境 (按键脚本 + 游戏主页)
echo ====================================================
echo   正在自动就绪环境：拉起 Runner 脚本并推进至 FGO 主页...
echo ====================================================
echo.
cd /d "%~dp0"
python -c "import sys; sys.path.insert(0, 'editor_v5'); import adb_sync; res = adb_sync.ready_environment(); print('\n>>> ' + res.get('message', str(res)))"
echo.
timeout /t 5

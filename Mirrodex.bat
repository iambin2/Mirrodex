@echo off
chcp 65001 >nul
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" goto window
for %%M in (guide add install uninstall) do if /i "%~1"=="%%M" goto window
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0mirrodex.ps1" %*
exit /b %errorlevel%
:window
start "" "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0mirrodex.ps1" %*
exit /b 0

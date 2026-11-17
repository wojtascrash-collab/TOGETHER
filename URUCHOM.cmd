@echo off
cd /d "%~dp0"
where node >nul 2>nul
if %errorlevel% equ 0 (
  set "TOGETHER_NODE=node"
) else (
  set "TOGETHER_NODE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
)
if "%TOGETHER_NODE%"=="node" goto run
if exist "%TOGETHER_NODE%" goto run
echo Zainstaluj Node.js 22 lub nowszy ze strony https://nodejs.org
pause
exit /b 1
:run
start "" "http://127.0.0.1:4173"
"%TOGETHER_NODE%" preview.mjs
pause

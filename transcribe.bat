@echo off
chcp 65001 >nul 2>&1

if "%~1"=="" (
    echo Usage: Drag and drop an MKV file onto this bat file.
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   MKV Transcribe + Minutes
echo ===========================================
echo.
echo Input: "%~1"
echo.

REM Convert Windows path: E:\Videos\foo.mkv -> /mnt/e/Videos/foo.mkv
set "WPATH=%~1"
set "WPATH=%WPATH:\=/%"
set "DRIVE=%WPATH:~0,1%"
call :LOWER %DRIVE% LDRIVE
set "WPATH=/mnt/%LDRIVE%%WPATH:~2%"

wsl -d dev bash -lc "cd /mnt/e/Videos && ./scripts/transcribe.sh \"%WPATH%\""

echo.
pause
exit /b 0

:LOWER
set "%2=%~1"
for %%a in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    call set "%2=%%%2:%%a=%%a%%"
)
exit /b

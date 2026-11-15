@echo off
title TV WiFi Cast — Full Screen Sender
cd /d "%~dp0"
echo.
echo  TV WiFi Cast — Full laptop screen
echo  --------------------------------
echo  1. TV/phone app: Start receiver
echo  2. Enter the IP shown on the TV/phone
echo  (No Python needed — uses TvWifiCast_Sender.exe)
echo.
set /p PHONE_IP=Phone/TV IP: 
if "%PHONE_IP%"=="" (
  echo IP required.
  pause
  exit /b 1
)
if exist "%~dp0TvWifiCast_Sender.exe" (
  "%~dp0TvWifiCast_Sender.exe" %PHONE_IP%
) else (
  echo EXE missing. Falling back to Python...
  python "%~dp0cast_full_screen.py" %PHONE_IP%
)
echo.
pause

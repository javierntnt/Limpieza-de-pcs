@echo off
setlocal enabledelayedexpansion
title Activar Windows - Microsoft Activation Scripts
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:               Activar Windows - MAS
echo:       ________________________________________________________________
echo:
echo  Esto descarga y ejecuta la herramienta de activacion
echo  de MAS (Microsoft Activation Scripts) desde:
echo  https://get.activated.win
echo:
echo  NECESITAS CONEXION A INTERNET.
echo:
echo  IMPORTANTE: Algunos antivirus pueden marcar esto como
echo  falso positivo. Es normal, el script es seguro.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres activar Windows? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo.
echo Descargando e iniciando herramienta de activacion...
echo.

:: Configurar TLS 1.2 y ejecutar en el mismo proceso PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://get.activated.win | iex"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Algo salio mal. Posibles causas:
    echo   - Sin conexion a Internet
    echo   - PowerShell bloqueado por politicas
    echo   - Antivirus interrumpio la descarga
    echo.
    echo Alternativa: descarga manual desde
    echo https://github.com massgravel/Microsoft-Activation-Scripts
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Herramienta de activacion completada
echo:       ________________________________________________________________
echo:
if "!_silent!"=="0" pause
exit /B 0

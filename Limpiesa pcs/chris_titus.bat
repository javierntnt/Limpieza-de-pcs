@echo off
setlocal enabledelayedexpansion
title WinUtil - Chris Titus Tech
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:               WinUtil - Chris Titus Tech
echo:       ________________________________________________________________
echo:
echo  Esto descarga y ejecuta la herramienta de optimizacion
echo  de Chris Titus directamente desde GitHub.
echo  NECESITAS CONEXION A INTERNET.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres lanzar WinUtil de Chris Titus? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo:
echo Descargando e iniciando WinUtil...
echo:

:: Configurar TLS 1.2 y ejecutar WinUtil en el MISMO proceso PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iwr -useb https://christitus.com/win | iex"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Algo salio mal. Posibles causas:
    echo   - Sin conexion a Internet
    echo   - PowerShell bloqueado
    echo.
    echo Alternativa: descarga manual desde
    echo https://github.com/ChrisTitusTech/winutil
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   WinUtil completado
echo:       ________________________________________________________________
echo:
if "!_silent!"=="0" pause
exit /B 0

@echo off
setlocal enabledelayedexpansion
title Liberador de Espacio en Disco
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Liberador de Espacio en Disco
echo:       ________________________________________________________________
echo:
echo  Ejecuta el Liberador de espacio en disco (cleanmgr)
echo  con las opciones que hayas configurado previamente.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres ejecutar el Liberador de espacio? [S/N] : "
    if errorlevel 2 (
        echo Operacion cancelada.
        pause
        exit /B 0
    )
)

echo.

:: Verificar si existe configuracion de Sageset
set "sagerun_configured="
for /F "skip=2 tokens=*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" 2^>nul') do (
    reg query "%%A" /v StateFlags0001 >nul 2>&1 && set "sagerun_configured=1"
)

if not defined sagerun_configured (
    echo:
    echo:       ________________________________________________________________
    echo:
    echo:                   Primera configuracion requerida
    echo:       ________________________________________________________________
    echo:
    echo  Se va a abrir el Liberador de espacio para que configures
    echo  las opciones de limpieza. Selecciona todo lo que quieras
    echo  limpiar, apreta ACEPTAR, y despues volve a ejecutar este script.
    echo:
    start cleanmgr /sageset:1
    if "!_silent!"=="0" pause
    exit /B 0
)

echo Ejecutando Liberador de espacio en disco...
echo (Paciencia, puede tardar varios minutos)
echo.
echo  NOTA: Si es la primera vez, se abrira una ventana para que
echo  configures que quieres limpiar. Selecciona todo y dale ACEPTAR.
echo  Despues vuelve a ejecutar este script para la limpieza real.

cleanmgr /sagerun:1

echo:
echo:       ________________________________________________________________
echo:
echo:                   Liberador de espacio completado
echo:       ________________________________________________________________
if "!_silent!"=="0" pause
exit /B 0

@echo off
setlocal enabledelayedexpansion
title Liberador de Espacio en Disco
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

:: Verificar permisos de Administrador
>nul 2>&1 net session
if %errorlevel% neq 0 (
    if "!_silent!"=="0" (
        echo.
        echo  [WARN] Este script requiere permisos de Administrador para acceder al registro de cleanmgr.
        echo  Intentando ejecucion sin admin - algunas funciones pueden limitarse.
    )
    set "_isAdmin=0"
) else (
    set "_isAdmin=1"
)

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

:: Verificar si existe configuracion de Sageset (solo si hay permisos de admin)
set "sagerun_configured="
if "%_isAdmin%"=="1" (
    for /F "skip=2 tokens=*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" 2^>nul') do (
        reg query "%%A" /v StateFlags0001 >nul 2>&1 && set "sagerun_configured=1"
    )
)

if not defined sagerun_configured (
    echo:
    echo:       ________________________________________________________________
    echo:
    echo:                   Primera configuracion requerida
    echo:       ________________________________________________________________
    echo:
    echo  Si tienes permisos de Administrador, se abrira el Liberador de espacio
    echo  para que configures las opciones de limpieza. Selecciona todo lo que quieras
    echo  limpiar, apreta ACEPTAR, y despues volve a ejecutar este script.
    echo  Si NO tienes permisos de admin, se ejecutara cleanmgr sin configuracion guardada.
    echo:
    if "%_isAdmin%"=="1" (
        start cleanmgr /sageset:1
        echo  Se abrio el Liberador de espacio para configuracion.
        echo  Configura las opciones deseadas y apreta ACEPTAR.
    ) else (
        echo  No hay permisos de admin - se ejecutara cleanmgr basico sin guardar configuracion.
    )
    if "!_silent!"=="0" pause
    exit /B 0
)

echo Ejecutando Liberador de espacio en disco...
echo (Paciencia, puede tardar varios minutos)
echo.
echo  NOTA: Si es la primera vez, el script intentara configurar cleanmgr automaticamente.

if "%_isAdmin%"=="1" (
    cleanmgr /sagerun:1
) else (
    cleanmgr
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Liberador de espacio completado
echo:       ________________________________________________________________
if "!_silent!"=="0" pause
exit /B 0

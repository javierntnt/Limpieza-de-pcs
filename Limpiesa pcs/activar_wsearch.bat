@echo off
setlocal enabledelayedexpansion
title Activar Windows Search
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Activar Windows Search (Indexacion)
echo:       ________________________________________________________________
echo:
echo  Reactiva el servicio de busqueda de Windows (WSearch)
echo  para que vuelva a indexar archivos y busquedas.
echo:

:: Verificar estado actual
sc query WSearch >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] El servicio WSearch no existe en este sistema.
    if "!_silent!"=="0" pause
    exit /B 1
)

:: Activar servicio
sc config WSearch start= auto >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] No se pudo configurar el servicio. Ejecuta como Administrador.
    if "!_silent!"=="0" pause
    exit /B 1
)

sc start WSearch >nul 2>&1
if %errorlevel% equ 0 (
    echo:
    echo:       ________________________________________________________________
    echo:
    echo:                   Windows Search activado
    echo:       ________________________________________________________________
    echo:
    echo  Windows Search activado y configurado para inicio automatico.
    echo  La indexacion comenzara automaticamente.
) else (
    echo:
    echo:       ________________________________________________________________
    echo:
    echo:                   Windows Search - Aviso
    echo:       ________________________________________________________________
    echo:
    echo  El servicio pudo ya estar corriendo o hay un problema menor.
    echo  La configuracion de inicio automatico se aplico correctamente.
)

echo:
if "!_silent!"=="0" pause
exit /B 0

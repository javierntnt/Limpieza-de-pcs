@echo off
setlocal enabledelayedexpansion
title Punto de Restauracion del Sistema
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Punto de Restauracion del Sistema
echo:       ________________________________________________________________
echo:
echo  Esto crea un punto de restauracion de Windows antes de hacer
echo  cualquier cambio en el sistema. Si algo sale mal despues, podes
echo  volver a este estado desde Restaurar Sistema.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres crear un punto de restauracion del sistema? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo.
echo Creando punto de restauracion...
echo.

:: Intentar con PowerShell (metodo moderno)
echo Probando metodo PowerShell...
powershell -NoProfile -Command "Checkpoint-Computer -Description 'Limpiesa PCS - Antes de optimizar' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1

if !errorlevel! equ 0 (
    echo ===============================================================================
    echo  LISTO. Punto de restauracion creado:
    echo  "Limpiesa PCS - Antes de optimizar"
    echo ===============================================================================
) else (
    echo [WARN] No se pudo crear con PowerShell. Probando metodo alternativo...
    
    :: Fallback con WMIC
    wmic.exe /Namespace:\\root\default Path SystemRestore Call Create "Limpiesa PCS - Antes de optimizar" >nul 2>&1
    
    if !errorlevel! equ 0 (
        echo ===============================================================================
        echo  LISTO. Punto de restauracion creado (metodo alternativo).
        echo ===============================================================================
    ) else (
        echo.
        echo ===============================================================================
        echo  ERROR: No se pudo crear el punto de restauracion.
        echo.
        echo  Posibles causas:
        echo   - No ejecutaste como Administrador
        echo   - La proteccion del sistema esta deshabilitada
        echo   - Hay otro punto de restauracion en progreso
        echo.
echo  Para activar la proteccion del sistema:
echo   1. Panel de Control ^> Sistema ^> Proteccion del Sistema
echo   2. Selecciona el disco y apreta "Configurar"
echo   3. Activa "Restaurar configuracion del sistema e
echo      versiones anteriores de archivos"
echo ===============================================================================
    )
)

echo.
if "!_silent!"=="0" pause
exit /B 0

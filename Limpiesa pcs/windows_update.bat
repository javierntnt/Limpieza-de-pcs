@echo off
setlocal enabledelayedexpansion
title Limpieza de Windows Update
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Limpieza de Cache de Windows Update
echo:       ________________________________________________________________
echo:
echo  Esto detiene servicios, renombra la carpeta de cache
echo  y la recrea limpia al reiniciar servicios.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres limpiar el cache de Windows Update? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo.

:: Detener servicios
echo [1/4] Deteniendo servicios de Windows Update...
net stop wuauserv /y >nul 2>&1
net stop bits /y >nul 2>&1
echo.

:: Renombrar carpeta (instantaneo - no hace falta tomar ownership)
echo [2/4] Renombrando carpeta SoftwareDistribution...
if exist "C:\Windows\SoftwareDistribution.old" (
    echo   [INFO] SoftwareDistribution.old ya existe, eliminando...
    rd /s /q "C:\Windows\SoftwareDistribution.old" >nul 2>&1
)
if exist "C:\Windows\SoftwareDistribution" (
    ren "C:\Windows\SoftwareDistribution" "SoftwareDistribution.old" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   ^- Carpeta renombrada a SoftwareDistribution.old
    ) else (
        echo   [WARN] No se pudo renombrar. Intentando limpieza directa...
        rd /s /q "C:\Windows\SoftwareDistribution" >nul 2>&1
    )
) else (
    echo   [INFO] Carpeta SoftwareDistribution no encontrada.
)
echo.

:: Crear carpeta nueva vacia (Windows la necesita para updates)
echo [3/4] Creando carpeta limpia...
if not exist "C:\Windows\SoftwareDistribution" (
    md "C:\Windows\SoftwareDistribution" >nul 2>&1
)
echo.

:: Re-iniciar servicios
echo [4/4] Reiniciando servicios...
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
echo.

echo:
echo:       ________________________________________________________________
echo:
echo:                   Cache de Windows Update limpiado
echo:       ________________________________________________________________
echo:
echo  La carpeta vieja quedo como SoftwareDistribution.old
echo  Reinicia la PC y borrala manual si queres.
if "!_silent!"=="0" pause
exit /B 0

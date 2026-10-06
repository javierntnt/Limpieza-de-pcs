@echo off
setlocal enabledelayedexpansion
title Limpieza de Prefetch
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Limpieza de Prefetch
echo:       ________________________________________________________________
echo:
echo  ADVERTENCIA: Limpiar Prefetch hace que las apps abran
echo  MAS LENTO la primera vez, hasta que Windows regenera
echo  los perfiles de carga.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Seguro queres limpiar Prefetch? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo.

if exist "C:\Windows\Prefetch" (
    set "filecount=0"
    for %%f in ("C:\Windows\Prefetch\*.*") do set /a filecount+=1
    echo Encontrados !filecount! archivos en Prefetch.
    del /f /s /q "C:\Windows\Prefetch\*.*" >nul 2>&1
    echo Prefetch limpio. Se eliminaron !filecount! archivos.
) else (
    echo [INFO] Carpeta Prefetch no encontrada o sin permisos.
    echo        Ejecuta como Administrador si necesitas limpiarlo.
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Prefetch limpio
echo:       ________________________________________________________________
echo:
echo  Recorda que las apps van a abrir mas lento
echo  hasta que Windows re-aprenda los patrones de carga.
if "!_silent!"=="0" pause
exit /B 0

@echo off
setlocal enabledelayedexpansion
title Limpieza del Visor de Eventos
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Limpieza del Visor de Eventos
echo:       ________________________________________________________________
echo:
echo  Esto borra TODOS los logs del sistema:
echo  Aplicacion, Seguridad, Sistema, Setup, PowerShell, etc.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres limpiar el Visor de Eventos? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo.
echo Limpiando... paciencia que son unos cuantos.
echo.

set "count=0"
for /F "tokens=*" %%G in ('wevtutil.exe el') do (
    set /a count+=1
    echo [%count%] Borrando log: %%G
    wevtutil.exe cl "%%G" >nul 2>&1
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Visor de Eventos limpio
echo:       ________________________________________________________________
echo:
echo  Se procesaron !count! registros.
if "!_silent!"=="0" pause
exit /B 0

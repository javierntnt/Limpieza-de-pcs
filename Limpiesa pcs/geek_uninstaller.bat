@echo off
setlocal enabledelayedexpansion
title Geek Uninstaller - Desinstalador Portable
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

set "_dir=%~dp0..\Herramientas\GeekUninstaller"
set "_exe=%_dir%\geek.exe"

echo:
echo:       ________________________________________________________________
echo:
echo:               Geek Uninstaller - Desinstalador Portable
echo:       ________________________________________________________________
echo:
echo  Desinstalador liviano de programas. Borra los restos del registro
echo  y de archivos que el desinstalador de Windows deja atras.
echo:

if not exist "%_exe%" (
    echo [AVISO] No se encontro la herramienta en:
    echo   %_exe%
    echo:
    if "!_silent!"=="1" exit /B 1
    choice /C SN /M "        Queres descargarla ahora desde el sitio oficial? [S/N] : "
    if errorlevel 2 exit /B 1
    echo:
    echo Descargando Geek Uninstaller...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $d='%_dir%'; New-Item -ItemType Directory -Force -Path $d ^| Out-Null; $z=Join-Path $env:TEMP 'geek.zip'; Invoke-WebRequest -Uri 'https://geekuninstaller.com/geek.zip' -OutFile $z -UseBasicParsing; Expand-Archive -LiteralPath $z -DestinationPath $d -Force; Remove-Item $z -Force"
    if not exist "%_exe%" (
        echo [ERROR] No se pudo descargar. Bajala manualmente de https://geekuninstaller.com
        if "!_silent!"=="0" pause
        exit /B 1
    )
    echo Listo.
    echo:
)

if "!_silent!"=="0" (
    choice /C SN /M "        Queres abrir Geek Uninstaller? [S/N] : "
    if errorlevel 2 exit /B 0
)

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo:
    echo [AVISO] No estas como Administrador: algunos programas no se van a
    echo         poder desinstalar y los restos no se podran borrar.
    echo         Geek Uninstaller te va a pedir elevacion cuando haga falta.
    echo:
)

echo Abriendo Geek Uninstaller...
start "" "%_exe%"
exit /B 0

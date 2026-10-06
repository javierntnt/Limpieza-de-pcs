@echo off
setlocal enabledelayedexpansion
title Verificacion del Sistema
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Verificacion del Sistema - SFC y Winget
echo:       ________________________________________________________________
echo:
echo  Esto va a:
echo    1. Ejecutar SFC /SCANNOW (verificar archivos del sistema)
echo    2. Buscar actualizaciones de programas con Winget
echo    3. Instalar actualizaciones de programas con Winget
echo:

:: ============================================================================
:: 1. SFC /SCANNOW
:: ============================================================================
echo:
echo  PASO 1: Verificador de Archivos del Sistema (SFC)
echo:
echo  SFC /SCANNOW revisa archivos protegidos de Windows y repara
echo  los que esten corruptos.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres ejecutar SFC /SCANNOW? [S/N] : "
    if errorlevel 2 goto SKIP_SFC
)

echo.
echo Ejecutando SFC /SCANNOW...
echo (Paciencia, puede tardar entre 5 y 30 minutos)
echo.
sfc /scannow
echo.
echo  SFC finalizado. Revisa el mensaje de arriba para ver el resultado.
goto FIN_SFC

:SKIP_SFC
echo ^- SFC omitido.

:FIN_SFC
echo.

:: ============================================================================
:: 2. WINGET - LISTAR ACTUALIZACIONES
:: ============================================================================
echo:
echo  PASO 2: Buscar actualizaciones de programas (Winget)
echo:
echo.
echo  Winget revisa actualizaciones disponibles para todos los programas
echo  instalados via Microsoft Store, GitHub y otros repos.
echo.

:: Verificar si winget esta disponible
winget --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Winget no esta instalado o no esta en el PATH.
    echo        Puedes instalarlo desde Microsoft Store buscando "App Installer".
    echo.
    goto SKIP_WINGET_LIST
)

if "!_silent!"=="0" (
    choice /C SN /M "        Queres buscar actualizaciones de programas con Winget? [S/N] : "
    if errorlevel 2 goto SKIP_WINGET_LIST
)

echo.
echo Buscando actualizaciones disponibles...
echo.
winget list --upgrade-available
echo.
echo  Arriba estan los programas con actualizaciones disponibles.
echo.

:: 3. WINGET - INSTALAR ACTUALIZACIONES
if "!_silent!"=="0" (
    choice /C SN /M "        Queres INSTALAR todas las actualizaciones disponibles? [S/N] : "
    if errorlevel 2 goto SKIP_WINGET_INSTALL
)

echo.
echo Instalando actualizaciones...
echo (Esto puede tardar varios minutos segun la cantidad)
echo.
winget upgrade --all
echo.
echo  Instalacion de actualizaciones finalizada.
echo  Puede que algunos programas requieran reiniciar.
goto FIN_WINGET

:SKIP_WINGET_INSTALL
echo ^- Instalacion omitida.
goto FIN_WINGET

:SKIP_WINGET_LIST
echo ^- Busqueda de actualizaciones omitida.

:FIN_WINGET
echo:
echo:       ________________________________________________________________
echo:
echo:                   VERIFICACION DEL SISTEMA FINALIZADA
echo:       ________________________________________________________________
if "!_silent!"=="0" pause
exit /B 0

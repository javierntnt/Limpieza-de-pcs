@echo off
setlocal enabledelayedexpansion
title Plan de Energia
color 07

:MENU_ENERGIA
cls
mode con cols=78 lines=34
echo:
echo:
echo:       ________________________________________________________________
echo:
echo:                     Plan de Energia del Sistema
echo:       ________________________________________________________________
echo:
echo:
echo:       Plan activo actual:
echo:
powercfg /getactivescheme
echo:
echo:       ________________________________________________________________
echo:
echo:       [1]  Alto Rendimiento
echo:            No apaga discos, maximo uso de CPU
echo:
echo:       [2]  Maximo Rendimiento
echo:            Ultimate Performance (Win 10/11)
echo:
echo:       [3]  Equilibrado
echo:            Default de fabrica, recomendado laptops
echo:
echo:       [4]  Economizador
echo:            Ahorra bateria
echo:
echo:       ________________________________________________________________
echo:
echo:       [5]  Ver todos los planes disponibles
echo:       [0]  Volver
echo:       ________________________________________________________________
echo:
echo:
choice /C:123450 /N /M "        Choose a menu option using your keyboard :"
set _erl=%errorlevel%

if %_erl%==1 goto PLAN1
if %_erl%==2 goto PLAN2
if %_erl%==3 goto PLAN3
if %_erl%==4 goto PLAN4
if %_erl%==5 goto VER_PLANES
if %_erl%==6 goto FIN_ENERGIA
goto MENU_ENERGIA

:VER_PLANES
cls
echo:
echo:       ________________________________________________________________
echo:
echo:                       Todos los Planes Disponibles
echo:       ________________________________________________________________
echo:
powercfg /list
echo:
echo:       ________________________________________________________________
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto MENU_ENERGIA

:PLAN1
cls
echo:
echo  Activando: Alto Rendimiento...
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
if %errorlevel% equ 0 (
    echo:
    echo  [OK] Plan cambiado a ALTO RENDIMIENTO.
) else (
    powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    if !errorlevel! equ 0 (
        echo:
        echo  [OK] Plan activado tras duplicar.
    ) else (
        echo:
        echo  [ERROR] No se pudo activar.
    )
)
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto MENU_ENERGIA

:PLAN2
cls
echo:
echo  Activando: Maximo Rendimiento...
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
if %errorlevel% equ 0 (
    echo:
    echo  [OK] Plan cambiado a MAXIMO RENDIMIENTO.
) else (
    echo:
    echo  [ERROR] No se pudo activar.
)
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto MENU_ENERGIA

:PLAN3
cls
echo:
echo  Activando: Equilibrado...
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
if %errorlevel% equ 0 (
    echo:
    echo  [OK] Plan cambiado a EQUILIBRADO.
) else (
    echo:
    echo  [ERROR] No se pudo activar.
)
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto MENU_ENERGIA

:PLAN4
cls
echo:
echo  Activando: Economizador (Ahorro de energia)...
powercfg -setactive a1841308-3541-4fab-bc81-f71556f20b4a >nul 2>&1
if %errorlevel% equ 0 (
    echo:
    echo  [OK] Plan cambiado a ECONOMIZADOR.
) else (
    echo:
    echo  [ERROR] No se pudo activar.
)
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto MENU_ENERGIA

:FIN_ENERGIA
exit /B 0

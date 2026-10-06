@echo off
setlocal enabledelayedexpansion
title Herramienta de Limpieza y Optimizacion

:: =============================================================================
:: HABILITAR COLORES ANSI
:: =============================================================================
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "Green=%ESC%[92m"
set "White=%ESC%[97m"
set "Reset=%ESC%[0m"

:: =============================================================================
:: VERIFICACION DE ADMINISTRADOR
:: =============================================================================
>nul 2>&1 net session
if %errorlevel% neq 0 (
    cls
    echo.
    echo %White% ==== ERROR ====
    echo.
    echo  Necesitas permisos de Administrador.
    echo  Solicitando permisos...%Reset%
    echo.
    set "vbs=%temp%\getadmin.vbs"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

:gotAdmin
@echo off
cd /d "%~dp0"

:MENU
@echo off
cls
mode con cols=85 lines=40
echo %White%
echo.
echo       %Green%Tip:%White% Para realizar un mantenimiento completo paso a paso, usa la opcion [T].
echo.
echo       -------------------------------------------------------------------------
echo.
echo               Opciones de Limpieza y Optimizacion:
echo.
echo               [1] Punto de Restauracion       - Seguridad
echo               [2] Temporales                  - Windows / Usuario
echo               [3] Cache Windows Update        - Sistema
echo               [4] Liberador de Espacio        - Disco
echo               [5] Visor de Eventos            - Logs
echo               [6] Servicios y Privacidad      - Optimizacion
echo               [7] Prefetch                    - Cache
echo.
echo       -------------------------------------------------------------------------
echo.
echo               [8] Inicio y Rendimiento        - Configuracion visual
echo               [9] Planes de Energia           - Sistema
echo               [10] Optimizacion Avanzada      - Rendimiento Profundo
echo               [11] Activar WSearch            - Indexacion
echo               [12] SFC y Winget               - Verificacion
echo.
echo       -------------------------------------------------------------------------
echo.
echo               [13] WinUtil (Chris Titus)      - Herramienta Externa
echo               [14] Activar Windows/Office     - MAS
echo.
echo       -------------------------------------------------------------------------
echo.
echo               [T] Ejecutar TODO               - Secuencial con confirmacion
echo               [0] Salir
echo.
echo       -------------------------------------------------------------------------
echo.
set /p "_opt=      %Green%Elige una opcion usando tu teclado [1,2...14,T,0] : %White%"

if /i "%_opt%"=="1"  goto OP1
if /i "%_opt%"=="2"  goto OP2
if /i "%_opt%"=="3"  goto OP3
if /i "%_opt%"=="4"  goto OP4
if /i "%_opt%"=="5"  goto OP5
if /i "%_opt%"=="6"  goto OP6
if /i "%_opt%"=="7"  goto OP7
if /i "%_opt%"=="8"  goto OP8
if /i "%_opt%"=="9"  goto OP9
if /i "%_opt%"=="10" goto OP10
if /i "%_opt%"=="11" goto OP11
if /i "%_opt%"=="12" goto OP12
if /i "%_opt%"=="13" goto OP13
if /i "%_opt%"=="14" goto OP14
if /i "%_opt%"=="T"  goto OPTODO
if /i "%_opt%"=="0"  goto SALIR
goto MENU

:: =============================================================================
:: OPCIONES INDIVIDUALES
:: =============================================================================

:OP1
cls & call restaurar_punto.bat & goto VOLVER
:OP2
cls & call Temp.bat & goto VOLVER
:OP3
cls & call windows_update.bat & goto VOLVER
:OP4
cls & call Cache.bat & goto VOLVER
:OP5
cls & call limpiar_visor_eventos.bat & goto VOLVER
:OP6
cls & call Limpieza_Servicios.bat & goto VOLVER
:OP7
cls & call Limpieza_sesion.bat & goto VOLVER
:OP8
cls & call desactivar_inicio.bat & goto VOLVER
:OP9
cls & call planes_energia.bat & goto VOLVER
:OP10
cls & call optimizar_rendimiento.bat & goto VOLVER
:OP11
cls & call activar_wsearch.bat & goto VOLVER
:OP12
cls & call verificar_sistema.bat & goto VOLVER
:OP13
cls & call chris_titus.bat & goto VOLVER
:OP14
cls & call activar_windows.bat & goto VOLVER

:VOLVER
@echo off
echo.
choice /C:0 /N /M "%Green%        Presiona [0] para volver al menu...%White%"
goto MENU

:: =============================================================================
:: EJECUTAR TODO - Logica Secuencial
:: =============================================================================

:OPTODO
@echo off
cls
mode con cols=85 lines=40
echo.
echo       %Green%-------------------------------------------------------------------------%White%
echo.
echo                      MANTENIMIENTO COMPLETO DEL SISTEMA
echo.
echo       %Green%-------------------------------------------------------------------------%White%
echo.
echo  Se ejecutara cada tarea en orden. Para cada una:
echo  %Green%[S]%White% Ejecuta la tarea actual y pasa a la siguiente.
echo  %Green%[N]%White% Omite la tarea actual y pasa a la siguiente.
echo.

echo %Green%[1/14]%White% Punto de Restauracion del Sistema...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT2
call restaurar_punto.bat /S
echo.

:TT2
echo %Green%[2/14]%White% Limpieza de Archivos Temporales...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT3
call Temp.bat /S
echo.

:TT3
echo %Green%[3/14]%White% Cache de Windows Update...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT4
call windows_update.bat /S
echo.

:TT4
echo %Green%[4/14]%White% Liberador de Espacio en Disco...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT5
call Cache.bat /S
echo.

:TT5
echo %Green%[5/14]%White% Visor de Eventos...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT6
call limpiar_visor_eventos.bat /S
echo.

:TT6
echo %Green%[6/14]%White% Optimizar Servicios y Privacidad...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT7
call Limpieza_Servicios.bat /S
echo.

:TT7
echo %Green%[7/14]%White% Limpieza de Prefetch...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT8
call Limpieza_sesion.bat /S
echo.

:TT8
echo %Green%[8/14]%White% Configurar Inicio y Rendimiento (interactivo)...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT9
call desactivar_inicio.bat
echo.

:TT9
echo %Green%[9/14]%White% Plan de Energia (abre submenu interactivo)...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT10
call planes_energia.bat
echo.

:TT10
echo %Green%[10/14]%White% Optimizar Rendimiento Avanzado...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT11
call optimizar_rendimiento.bat /S
echo.

:TT11
echo %Green%[11/14]%White% Activar Windows Search...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT12
call activar_wsearch.bat /S
echo.

:TT12
echo %Green%[12/14]%White% Verificar Sistema (SFC / Winget)...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT13
call verificar_sistema.bat /S
echo.

:TT13
echo %Green%[13/14]%White% WinUtil de Chris Titus...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto TT14
call chris_titus.bat /S
echo.

:TT14
echo %Green%[14/14]%White% Activar Windows (MAS)...
choice /C SN /N /M "        Ejecutar esta tarea? [S/N] : "
if errorlevel 2 goto FINAL_TODO
call activar_windows.bat /S
echo.

:FINAL_TODO
echo       %Green%-------------------------------------------------------------------------%White%
echo.
echo                     MANTENIMIENTO FINALIZADO
echo.
echo       %Green%-------------------------------------------------------------------------%White%
echo.
choice /C:0 /N /M "%Green%        Presiona [0] para volver al menu...%White%"
goto MENU

:SALIR
echo %Reset%
exit /B 0
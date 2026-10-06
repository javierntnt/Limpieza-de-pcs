@echo off
setlocal enabledelayedexpansion
title Configuracion de Inicio y Rendimiento
color 07

echo:
echo:       ________________________________________________________________
echo:
echo:           Configuracion: Inicio, Servicios y Rendimiento
echo:       ________________________________________________________________
echo:
echo  Te voy a ir abriendo las ventanas una por una para que configures:
echo    - Programas de inicio (Task Manager)
echo    - Aplicaciones de inicio (Configuracion)
echo    - Rendimiento visual (Efectos)
echo    - Aplicaciones en segundo plano
echo:
choice /C SN /M "        Queres abrir las herramientas de configuracion? [S/N] : "
if errorlevel 2 (
    echo Operacion cancelada.
    pause
    exit /B 0
)

echo.

echo -------------------------------------------------------------------------------
echo PASO 1: ADMINISTRADOR DE TAREAS (Programas de inicio)
echo -------------------------------------------------------------------------------
echo  Ve a la pestana "Inicio" y deshabilita lo que no necesites.
echo.
start taskmgr
pause
echo.

echo -------------------------------------------------------------------------------
echo PASO 2: CONFIGURACION DE APLICACIONES DE INICIO
echo -------------------------------------------------------------------------------
echo  Configuracion ^> Aplicaciones ^> Inicio
echo.
start ms-settings:startupapps
pause
echo.

echo -------------------------------------------------------------------------------
echo PASO 3: OPCIONES DE RENDIMIENTO DE WINDOWS
echo -------------------------------------------------------------------------------
echo  Elegi "Ajustar para obtener el mejor rendimiento".
echo.
start SystemPropertiesPerformance.exe
pause
echo.

echo -------------------------------------------------------------------------------
echo PASO 4: APLICACIONES EN SEGUNDO PLANO
echo -------------------------------------------------------------------------------
echo  Configuracion ^> Privacidad ^> Aplicaciones en segundo plano.
echo.
start ms-settings:privacy-backgroundapps
pause
echo.

echo ===============================================================================
echo  LISTO. Ya configuraste todo.
echo.
echo  RESUMEN de lo que configuraste:
echo   - Programas de inicio: deshabilita los que no necesites
echo   - Apps de inicio: revisa en Configuracion
echo   - Rendimiento visual: ajusta segun tu preferencia
echo   - Apps en segundo plano: desactiva las que no usas
echo.
echo  RECOMENDACION: Deshabilita todo lo que no reconozcas.
echo  Si algo deja de funcionar, podes reactivarlo desde ahi.
echo ===============================================================================
pause
exit /B 0

@echo off
setlocal enabledelayedexpansion
title Liberador de Espacio en Disco
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

:: Tope de espera (segundos) para cleanmgr.
:: Windows tiene un bug conocido: cleanmgr /sagerun se queda colgado al llegar
:: al 100% esperando movimiento del mouse. Sin este tope, la automatizacion
:: nunca avanza a la tarea siguiente.
set "_cleanmgr_max_wait=90"

:: Verificar permisos de Administrador
net session >nul 2>&1
if %errorlevel% equ 0 (
    set "_isAdmin=1"
) else (
    set "_isAdmin=0"
)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Liberador de Espacio en Disco
echo:       ________________________________________________________________
echo:
echo  Ejecuta el Liberador de espacio en disco (cleanmgr)
echo  con las opciones que hayas configurado previamente.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres ejecutar el Liberador de espacio? [S/N] : "
    if errorlevel 2 (
        echo Operacion cancelada.
        pause
        exit /B 0
    )
)

echo.

:: Detectar si cleanmgr ya tiene una configuracion guardada (StateFlags0001).
:: Leer el registro NO requiere admin, por eso se detecta siempre.
set "sagerun_configured="
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" /s /v StateFlags0001 >nul 2>&1
if %errorlevel% equ 0 set "sagerun_configured=1"

if not defined sagerun_configured goto SIN_CONFIG
if "!_isAdmin!"=="1" goto CON_ADMIN
goto SIN_ADMIN

:: -----------------------------------------------------------------------------
:: Caso 1: hay configuracion guardada y hay admin -> limpieza automatica
:: -----------------------------------------------------------------------------
:CON_ADMIN
echo  [MODO] Configuracion guardada detectada - cleanmgr /sagerun:1
echo  Se lanza la limpieza y se espera a que termine.
echo.
echo  NOTA: cleanmgr puede quedarse en 100%% sin cerrarse por un bug de Windows.
echo        Si pasa, se espera hasta %_cleanmgr_max_wait%s como maximo y se sigue
echo        con la tarea siguiente.
echo.
start "" /min cleanmgr /sagerun:1
set "_waited=0"

:WAIT_CLEANMGR
tasklist /fi "imagename eq cleanmgr.exe" 2>nul | find /i "cleanmgr.exe" >nul
if errorlevel 1 goto CLEANMGR_LISTO
set /a "_waited=_waited+5" >nul 2>&1
if !_waited! geq %_cleanmgr_max_wait% goto CLEANMGR_TIMEOUT
echo   ... limpiando, esperando a cleanmgr: !_waited!s de %_cleanmgr_max_wait%s
ping -n 6 127.0.0.1 >nul
goto WAIT_CLEANMGR

:CLEANMGR_TIMEOUT
echo.
echo  [WARN] cleanmgr sigue abierto tras %_cleanmgr_max_wait%s.
echo         La limpieza ya termino; se continua con la tarea siguiente.
echo         Podes cerrar la ventana de cleanmgr cuando quieras.
goto LISTO

:CLEANMGR_LISTO
echo.
echo  [OK] cleanmgr finalizo.
goto LISTO

:: -----------------------------------------------------------------------------
:: Caso 2: hay configuracion guardada pero NO hay admin
:: -----------------------------------------------------------------------------
:SIN_ADMIN
echo  [WARN] Hay configuracion guardada, pero no hay permisos de Administrador.
if "!_silent!"=="0" (
    echo         Se abrira el Liberador en modo basico.
    echo.
    cleanmgr
) else (
    echo         En modo automatico se omite para no bloquear la secuencia.
    echo         Ejecuta este script como Administrador para limpiar el disco.
)
goto LISTO

:: -----------------------------------------------------------------------------
:: Caso 3: no hay configuracion guardada de cleanmgr
:: -----------------------------------------------------------------------------
:SIN_CONFIG
echo  [MODO] No hay configuracion guardada de cleanmgr.
if "!_isAdmin!"=="1" (
    echo         Se abre la ventana de configuracion. Marca lo que quieras limpiar
    echo         y apreta ACEPTAR. Despues volve a ejecutar esta tarea.
    echo.
    start "" cleanmgr /sageset:1
) else (
    echo         Sin permisos de Administrador no se puede configurar cleanmgr.
    echo         Ejecuta este script como Administrador para configurarlo.
)
goto LISTO

:: -----------------------------------------------------------------------------
:: Cierre - siempre retorna al flujo (en modo automatico avanza a la siguiente)
:: -----------------------------------------------------------------------------
:LISTO
echo:
echo:       ________________________________________________________________
echo:
echo:                   Liberador de espacio completado
echo:       ________________________________________________________________
echo.
echo  Tarea finalizada. Continuando...
if "!_silent!"=="0" pause
exit /B 0

@echo off
setlocal enabledelayedexpansion
color 07
title Service Killer Lite V23.5

:: Verificar administrador
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    cls
    echo.
    echo  ==== ERROR ====
    echo.
    echo  Necesitas permisos de Administrador.
    echo  Right click and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

:MENU
cls
mode con cols=78 lines=34
echo:
echo:
echo:       ________________________________________________________________
echo:
echo:              LatencyLabs - Service Killer Lite V23.5
echo:       ________________________________________________________________
echo:
echo:
echo:       [1]  Modo Seguro
echo:            Telemetria y basura estandar
echo:
echo:       [2]  Modo Extremo
echo:            Xbox, Store, Updates, etc
echo:
echo:       [3]  Modo Panico
echo:            Revertir todo a valores de fabrica
echo:
echo:       ________________________________________________________________
echo:
echo:       [0]  Salir
echo:       ________________________________________________________________
echo:
echo:
choice /C:1230 /N /M "        Choose a menu option using your keyboard :"
set _erl=%errorlevel%

if %_erl%==1 goto :modo_estandar
if %_erl%==2 goto :modo_avanzado
if %_erl%==3 goto :revertir
if %_erl%==4 goto :salir
goto :MENU

:modo_estandar
cls
echo:
echo  Aplicando purga de Telemetria...
echo:
call :payload_estandar
echo:
echo  [OK] Purga de telemetria completada.
echo  Reinicia la PC para que aplique.
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto :MENU

:payload_estandar
:: Detener y deshabilitar servicios
for %%s in (DiagTrack dmwappushservice diagsvc DPS WerSvc AJRouter ALG PeerDistSvc RemoteRegistry WebClient MapsBroker lfsvc AppMgmt RetailDemo SCardSvr TapiSrv TrkWks fhsvc WalletService IEEtwCollectorService WMPNetworkSvc) do (
    sc stop %%s >nul 2>&1
    sc config %%s start= disabled >nul 2>&1
)
:: Matar procesos basura
taskkill /f /im CompPkgSrv.exe >nul 2>&1
taskkill /f /im CompatTelRunner.exe >nul 2>&1
taskkill /f /im SmartScreen.exe >nul 2>&1
exit /b

:modo_avanzado
cls
echo:
echo:       ________________________________________________________________
echo:
echo:                    Modo Extremo - Configuracion
echo:       ________________________________________________________________
echo:
echo:
echo  [1] IMPRESORAS
choice /C SN /M "        Desactivar Spooler? [S/N] : "
if %errorlevel% equ 1 set "DES_IMPRESORA=si"
echo:
echo  [2] XBOX Y GAME BAR
choice /C SN /M "        Desactivar Xbox y Game Bar? [S/N] : "
if %errorlevel% equ 1 set "DES_XBOX=si"
echo:
echo:       ________________________________________________________________
echo:

echo Ejecutando limpieza profunda...
call :payload_estandar

if "!DES_IMPRESORA!"=="si" (
    sc stop Spooler >nul 2>&1
    sc config Spooler start= disabled >nul 2>&1
    echo  [OK] Spooler (impresoras) deshabilitado
)

if "!DES_XBOX!"=="si" (
    for %%s in (XboxGipSvc XblAuthManager XblGameSave XboxNetApiSvc) do (
        sc stop %%s >nul 2>&1
        sc config %%s start= disabled >nul 2>&1
    )
    taskkill /f /im GameBar.exe >nul 2>&1
    taskkill /f /im GameBarPresenceWriter.exe >nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f >nul 2>&1
    echo  [OK] Xbox y Game Bar deshabilitados
)

echo:
echo  [OK] Purga extrema completada.
echo  Reinicia la PC para que aplique.
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto :MENU

:revertir
cls
echo:
echo  Restaurando valores de fabrica...
echo:

:: Restaurar servicios de Xbox
for %%s in (XboxGipSvc XblAuthManager XblGameSave XboxNetApiSvc) do (
    sc config %%s start= demand >nul 2>&1
    echo  [OK] %%s restaurado a demanda
)

:: Restaurar Game DVR
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
echo  [OK] Game DVR restaurado

:: Restaurar servicios de telemetria
for %%s in (DiagTrack dmwappushservice) do (
    sc config %%s start= demand >nul 2>&1
    echo  [OK] %%s restaurado a demanda
)

:: Restaurar Spooler
sc config Spooler start= auto >nul 2>&1
echo  [OK] Spooler (impresoras) restaurado

echo:
echo  [OK] Valores de fabrica restaurados.
echo  REINICIA la PC para que aplique todo.
echo:
choice /C:0 /N /M "        Press [0] to go back..."
goto :MENU

:salir
exit

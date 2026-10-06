@echo off
setlocal enabledelayedexpansion
title Optimizador de Servicios y Privacidad
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Optimizacion de Servicios y Privacidad
echo:       ________________________________________________________________
echo:
echo  Esto va a deshabilitar:
echo    - Cortana
echo    - Telemetria (DiagTrack, dmwappush)
echo    - Servicios innecesarios (Tablet, Mapas, GPS, Insider)
echo    - Xbox Game Bar y capturas
echo    - Permisos de privacidad de apps
echo:
echo  NOTA: Print Spooler (impresoras) NO se toca.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres optimizar los servicios del sistema? [S/N] : "
    if errorlevel 2 (
        echo Operacion cancelada.
        pause
        exit /B 0
    )
)

echo.

:: 1. DESHABILITAR CORTANA
echo [1/5] Deshabilitando Cortana...
taskkill /f /im Cortana.exe >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f >nul 2>&1
echo   ^- Cortana deshabilitada

:: 2. DESHABILITAR SERVICIOS DE TELEMETRIA
echo [2/5] Deshabilitando servicios de telemetria...
sc stop DiagTrack >nul 2>&1
sc config DiagTrack start= disabled >nul 2>&1
echo   ^- DiagTrack detenido y deshabilitado
sc stop dmwappushservice >nul 2>&1
sc config dmwappushservice start= disabled >nul 2>&1
echo   ^- dmwappushservice detenido y deshabilitado

:: 3. DESHABILITAR SERVICIOS INNECESARIOS
echo [3/5] Deshabilitando servicios innecesarios...
sc stop TabletInputService >nul 2>&1
sc config TabletInputService start= disabled >nul 2>&1
echo   ^- TabletInputService (Tablet/Pen)
sc stop MapsBroker >nul 2>&1
sc config MapsBroker start= disabled >nul 2>&1
echo   ^- MapsBroker (Mapas descargados)
sc stop lfsvc >nul 2>&1
sc config lfsvc start= disabled >nul 2>&1
echo   ^- lfsvc (Geolocalizacion)
sc stop wisvc >nul 2>&1
sc config wisvc start= disabled >nul 2>&1
echo   ^- wisvc (Windows Insider)

:: 4. XBOX GAME BAR Y CAPTURAS
echo [4/5] Deshabilitando Xbox Game Bar y capturas...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
echo   ^- Xbox Game Bar deshabilitada

:: 5. BLOQUEO DE PRIVACIDAD
echo [5/5] Bloqueando permisos de privacidad de apps...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\tasks" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios" /v "Value" /t REG_SZ /d "Deny" /f >nul 2>&1
echo   ^- Permisos bloqueados (contactos, llamadas, sms, radio)

echo:
echo:       ________________________________________________________________
echo:
echo:                   Proceso completado
echo:       ________________________________________________________________
echo:
echo  Servicios modificados:
echo   - Cortana: deshabilitada
echo   - Telemetria: DiagTrack, dmwappush deshabilitados
echo   - Tablet, Mapas, GPS, Insider: deshabilitados
echo   - Xbox Game Bar: deshabilitada
echo   - Privacidad: contactos, llamadas, radio bloqueados
echo:
echo  Servicios RESPETADOS (no se tocaron):
echo   - Windows Update (wuauserv)
echo   - Windows Search (WSearch)
echo   - Print Spooler (impresoras)
if "!_silent!"=="0" pause
exit /B 0

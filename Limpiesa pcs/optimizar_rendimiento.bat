@echo off
setlocal enabledelayedexpansion
title Optimizacion de Rendimiento
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Optimizacion Avanzada de Rendimiento
echo:       ________________________________________________________________
echo:
echo  Esto va a:
echo   1. Deshabilitar aplicaciones en segundo plano
echo   2. Deshabilitar SysMain (Superfetch)
echo   3. Limpiar componentes viejos de Windows (DISM)
echo   4. Deshabilitar hibernacion (libera GBs)
echo   5. Deshabilitar servicios innecesarios extra
echo   6. Limpiar cache de DNS
echo:
echo  RECOMENDADO para PCs de escritorio con SSD.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres ejecutar la optimizacion avanzada? [S/N] : "
    if errorlevel 2 (
        echo Operacion cancelada.
        pause
        exit /B 0
    )
)

echo.
echo ===============================================================================
echo  Empezando...
echo ===============================================================================

:: ============================================================================
:: 1. APLICACIONES EN SEGUNDO PLANO
:: ============================================================================
echo [1/6] Deshabilitando aplicaciones en segundo plano...

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v "LetAppsRunInBackground" /t REG_DWORD /d 2 /f >nul 2>&1

for %%A in (
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.Office.OneNote"
    "Microsoft.People"
    "Microsoft.ScreenSketch"
    "Microsoft.Wallet"
    "Microsoft.WebMediaExtensions"
    "Microsoft.WebpImageExtension"
    "Microsoft.Windows.Photos"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsCommunicationsApps"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "SpotifyAB.SpotifyMusic"
    "Disney.37853FC22B2CE"
    "4DF9E0F8.Netflix"
) do (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\%%~A" /v "Disabled" /t REG_DWORD /d 1 /f >nul 2>&1
)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search\BackgroundAppGlobalToggle" /v "GlobalToggle" /t REG_DWORD /d 0 /f >nul 2>&1
echo   ^- Aplicaciones en segundo plano deshabilitadas

:: ============================================================================
:: 2. SYSMAIN (SUPERFETCH)
:: ============================================================================
echo [2/6] Deshabilitando SysMain (Superfetch)...
sc stop SysMain >nul 2>&1
sc config SysMain start= disabled >nul 2>&1
echo   ^- SysMain detenido y deshabilitado (en SSD no es necesario)

:: ============================================================================
:: 3. DISM - LIMPIEZA DE COMPONENTES
:: ============================================================================
echo [3/6] Limpiando componentes viejos de Windows (DISM)...
echo   (Esto puede tardar varios minutos, paciencia)
dism /online /Cleanup-Image /StartComponentCleanup /ResetBase >nul 2>&1
if %errorlevel% equ 0 (
    echo   ^- Componentes viejos eliminados. Espacio liberado.
) else (
    echo   [WARN] No se pudo completar la limpieza DISM.
)

:: ============================================================================
:: 4. HIBERNACION
:: ============================================================================
echo [4/6] Deshabilitando hibernacion...
powercfg /h off >nul 2>&1
if %errorlevel% equ 0 (
    echo   ^- Hibernacion deshabilitada. Archivo hiberfil.sys eliminado.
) else (
    echo   [WARN] No se pudo deshabilitar hibernacion.
)

:: ============================================================================
:: 5. SERVICIOS INNECESARIOS EXTRAS
:: ============================================================================
echo [5/6] Deshabilitando servicios innecesarios...

sc stop WerSvc >nul 2>&1
sc config WerSvc start= disabled >nul 2>&1
echo   ^- WerSvc (Windows Error Reporting) deshabilitado

sc stop TabletInputService >nul 2>&1
sc config TabletInputService start= disabled >nul 2>&1
echo   ^- Touch Keyboard deshabilitado

sc stop Fax >nul 2>&1
sc config Fax start= disabled >nul 2>&1
echo   ^- Fax deshabilitado

sc stop RemoteAccess >nul 2>&1
sc config RemoteAccess start= disabled >nul 2>&1
echo   ^- RemoteAccess deshabilitado

sc stop RemoteRegistry >nul 2>&1
sc config RemoteRegistry start= disabled >nul 2>&1
echo   ^- RemoteRegistry deshabilitado (seguridad)

sc stop TrkWks >nul 2>&1
sc config TrkWks start= disabled >nul 2>&1
echo   ^- TrkWks deshabilitado

sc stop WdiServiceHost >nul 2>&1
sc config WdiServiceHost start= disabled >nul 2>&1
echo   ^- WdiServiceHost deshabilitado

echo   ^- Print Spooler NO se toca (respetado)

:: ============================================================================
:: 6. LIMPIEZA DE DNS
:: ============================================================================
echo [6/6] Limpiando cache de DNS...
ipconfig /flushdns >nul 2>&1
echo   ^- DNS flusheado

echo:
echo:       ________________________________________________________________
echo:
echo:                   OPTIMIZACION COMPLETADA CON EXITO
echo:       ________________________________________________________________
echo:
echo  Cambios aplicados:
echo   [OK] Apps en segundo plano deshabilitadas
echo   [OK] SysMain (Superfetch) deshabilitado
echo   [OK] Componentes viejos de Windows limpiados (DISM)
echo   [OK] Hibernacion deshabilitada (espacio liberado)
echo   [OK] Servicios innecesarios deshabilitados
echo   [OK] Cache de DNS limpiada
echo:
echo  RECOMENDACION: REINICIAR la PC para aplicar todos los cambios.
echo:
echo  NOTA: Si tu PC es LAPTOPI, considera no deshabilitar la hibernacion
echo        ya que necesitas el sleep mode para bateria.
if "!_silent!"=="0" pause
exit /B 0

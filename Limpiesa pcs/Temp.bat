@echo off
setlocal enabledelayedexpansion
title Limpieza de Archivos Temporales
color 07

:: Verificar parametro /S (silencioso - sin preguntas)
set "_silent=0"
for %%A in (%*) do if /i "%%A"=="/S" set "_silent=1"

echo:
echo:       ________________________________________________________________
echo:
echo:                   Limpieza de Archivos Temporales
echo:       ________________________________________________________________
echo:
echo  Esto limpia %%TEMP%% del usuario y C:\Windows\Temp.
echo  Tambien limpia archivos .tmp, thumbs.db, y otros residuos.
echo:

if "!_silent!"=="0" (
    choice /C SN /M "        Queres limpiar los archivos temporales? [S/N] : "
    if errorlevel 2 exit /B 0
)

echo:

:: Limpiar %%TEMP%% del usuario (solo contenido, no la carpeta)
echo [1/4] Limpiando carpeta temporal de usuario...
if exist "%temp%" (
    del /f /s /q "%temp%\*.*" >nul 2>&1
    for /d %%i in ("%temp%\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
    echo   ^- Listo: %%TEMP%% del usuario limpio.
) else (
    echo   [INFO] %%TEMP%% no existe o no es accesible.
)
echo.

:: Limpiar C:\Windows\Temp
echo [2/4] Limpiando C:\Windows\Temp...
if exist "C:\Windows\Temp" (
    del /f /s /q "C:\Windows\Temp\*.*" >nul 2>&1
    for /d %%i in ("C:\Windows\Temp\*") do (
        rd /s /q "%%i" >nul 2>&1
    )
    echo   ^- Listo: C:\Windows\Temp limpio.
) else (
    echo   [INFO] C:\Windows\Temp no encontrado.
)
echo.

:: Limpiar thumbnails cache
echo [3/4] Limpiando cache de thumbnails...
if exist "%LocalAppData%\Microsoft\Windows\Explorer" (
    del /f /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
    echo   ^- Cache de thumbnails limpio.
) else (
    echo   [INFO] Carpeta de thumbnails no encontrada.
)
echo.

:: Limpiar archivos .tmp sueltos en carpetas comunes
echo [4/4] Limpiando archivos residuales (.tmp, .log viejos)...
del /f /s /q "%temp%\*.tmp" >nul 2>&1
del /f /s /q "%temp%\*.log" >nul 2>&1
echo   ^- Archivos residuales eliminados.

echo:
echo:       ________________________________________________________________
echo:
echo:                   LIMPIEZA DE TEMPORALES COMPLETADA
echo:       ________________________________________________________________
echo:
echo  NOTA: Algunos archivos en uso no se borraron, es normal.
if "!_silent!"=="0" pause
exit /B 0

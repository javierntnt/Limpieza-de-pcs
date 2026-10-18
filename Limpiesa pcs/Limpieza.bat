@echo off
:: ---------------------------------------------------------------------------
:: Lanzador del motor PowerShell de Limpieza de PCs
::
:: Doble clic para abrir el menu interactivo.
:: Tambien acepta argumentos desde una consola:
::   Limpieza.bat -All             mantenimiento completo, secuencial
::   Limpieza.bat -DryRun -All     simula todo sin tocar el sistema
::   Limpieza.bat -Task 2,4        solo las tareas indicadas
::   Limpieza.bat -Force -All      ignora las omisiones por hardware/politica
:: ---------------------------------------------------------------------------
title Limpieza de PCs - Motor PowerShell

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Limpieza.ps1" %*
set "_rc=%errorlevel%"

echo.
if not "%_rc%"=="0" echo  [ERROR] El motor termino con codigo %_rc%.
echo  Presiona una tecla para cerrar esta ventana...
pause >nul
exit /B %_rc%

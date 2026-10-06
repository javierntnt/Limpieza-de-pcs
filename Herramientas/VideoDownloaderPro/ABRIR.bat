@echo off
chcp 65001 >nul
setlocal enableextensions
title Video Downloader Pro

pushd "%~dp0"
set "APP=%~dp0video_downloader.py"
set "MARKER=%~dp0.vdlp_ready"

REM ============================================================
REM  1) Detectar Python  (probamos "python" y luego "py")
REM ============================================================
call :detect_python
if defined PYCMD goto have_python

REM --- No hay Python: intentamos instalarlo solos con winget ---
where winget >nul 2>&1
if errorlevel 1 goto no_python

echo.
echo  ============================================
echo    Python no encontrado. Instalando solo...
echo    (esto solo pasa una vez y puede tardar)
echo  ============================================
echo.
winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements
echo.
echo  Refrescando entorno...
call :refresh_path
call :detect_python
if defined PYCMD goto have_python

REM A veces el PATH no se actualiza hasta reabrir la ventana
echo.
echo  [INFO] Python ya se ha instalado, pero hay que reabrir este archivo.
echo  Cierra esta ventana y vuelve a abrir ABRIR.bat   (un doble clic mas).
echo.
pause
popd
exit /b 0

:have_python

REM ============================================================
REM  2) Comprobar que la app esta en la misma carpeta
REM ============================================================
if not exist "%APP%" goto no_app

REM ============================================================
REM  3) Solo prepara dependencias la PRIMERA vez (o si falta yt-dlp)
REM     El resto de veces abre directo y rapido.
REM ============================================================
if not exist "%MARKER%" goto setup
%PYCMD% -c "import yt_dlp" >nul 2>&1 || goto setup
goto run

:setup
echo.
echo  ============================================
echo    VIDEO DOWNLOADER PRO  -  Preparando todo
echo  ============================================
echo.
echo  Instalando/actualizando yt-dlp (esto solo se hace una vez)...
%PYCMD% -m pip install -q --upgrade yt-dlp
if errorlevel 1 goto pip_error
echo  [OK] yt-dlp listo.
echo.

ffmpeg -version >nul 2>&1
if errorlevel 1 (
  echo  FFmpeg no encontrado. Intentando instalarlo solo...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo  [AVISO] No se pudo instalar FFmpeg automaticamente ^(no hay winget^).
    echo          La app funciona igual, pero NO podra convertir para Premiere.
    echo          Para instalarlo, abre PowerShell y pega:
    echo              winget install Gyan.FFmpeg
    echo.
  ) else (
    winget install -e --id Gyan.FFmpeg --scope user --silent --accept-package-agreements --accept-source-agreements
    call :refresh_path
    ffmpeg -version >nul 2>&1
    if errorlevel 1 (
      echo  [AVISO] FFmpeg instalado pero aun no visible en esta sesion.
      echo          Se activara la proxima vez que abras ABRIR.bat.
      echo.
    ) else (
      echo  [OK] FFmpeg instalado y listo.
      echo.
    )
  )
) else (
  echo  [OK] FFmpeg encontrado.
  echo.
)

REM Marca de "ya preparado" para que las proximas veces abra al instante
> "%MARKER%" echo listo
echo  Todo listo. Iniciando la aplicacion...
echo.

:run
%PYCMD% "%APP%"
if errorlevel 1 pause
popd
exit /b 0

REM ============================================================
REM  SUBRUTINAS
REM ============================================================

:detect_python
set "PYCMD="
python --version >nul 2>&1 && set "PYCMD=python"
if not defined PYCMD py --version >nul 2>&1 && set "PYCMD=py"
exit /b 0

:refresh_path
REM Reconstruye el PATH leyendo del registro (sin reiniciar la ventana)
set "SYSPATH="
set "USERPATH="
for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSPATH=%%B"
for /f "skip=2 tokens=2,*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USERPATH=%%B"
if defined USERPATH (
  set "PATH=%SYSPATH%;%USERPATH%"
) else (
  set "PATH=%SYSPATH%"
)
exit /b 0

:no_python
echo.
echo  [ERROR] No se ha encontrado Python y no se pudo instalar automaticamente.
echo.
echo  Descargalo GRATIS aqui:   https://www.python.org/downloads
echo  IMPORTANTE: durante la instalacion marca la casilla
echo  "Add Python to PATH" antes de pulsar Instalar.
echo.
pause
popd
exit /b 1

:no_app
echo.
echo  [ERROR] No encuentro "video_downloader.py" en esta carpeta.
echo  Este .bat tiene que estar en la MISMA carpeta que la app.
echo  (Si lo abriste desde dentro del .zip, extrae primero la carpeta.)
echo.
pause
popd
exit /b 1

:pip_error
echo.
echo  [ERROR] No se pudo instalar yt-dlp.
echo  Comprueba tu conexion a internet y vuelve a abrir este archivo.
echo.
pause
popd
exit /b 1

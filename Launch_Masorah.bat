@echo off
setlocal
title Masorah Corpus Engine v40.1
color 0A

REM Always run from THIS file's folder
cd /d "%~dp0"
set "DIR=%~dp0"

echo.
echo  ================================================
echo   MASORAH CORPUS WORKBENCH v40.1
echo   Mark Corley - FAU/TAU PhD Research Platform
echo   Folder: %DIR%
echo  ================================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python not found. Install Python 3.10+ and add to PATH.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('python --version 2^>^&1') do echo  [OK] %%v

REM Check main_api.py is here
if not exist "%DIR%main_api.py" (
    echo  [ERROR] main_api.py not found in %DIR%
    echo  All files must be in the same folder as this .bat file.
    echo.
    pause
    exit /b 1
)
echo  [OK] main_api.py found

REM Install dependencies
echo  [*] Installing dependencies - this can take a moment on first run...
python -m pip install fastapi "uvicorn[standard]" pillow python-multipart --quiet --disable-pip-version-check 2>nul
if exist "%DIR%requirements.txt" (
    python -m pip install -r "%DIR%requirements.txt" --quiet --disable-pip-version-check 2>nul
)
echo  [OK] Dependencies ready

REM Kill anything already on port 8000
for /f "tokens=5" %%p in ('netstat -aon 2^>nul ^| findstr /R ":8000 "') do (
    taskkill /f /pid %%p >nul 2>&1
)

REM Start API server - cwd is already %DIR% from the cd /d above, no /D needed
echo  [*] Starting API server on port 8000...
set "CMD=python -m uvicorn main_api:app --host 0.0.0.0 --port 8000 --reload"
start "Masorah API" cmd /k %CMD%

REM Wait up to 20 seconds for server
echo  [*] Waiting for server...
set TRIES=0
:WAIT
timeout /t 2 /nobreak >nul
python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000',timeout=1)" >nul 2>&1
if not errorlevel 1 goto READY
set /a TRIES+=1
if %TRIES% lss 10 goto WAIT
echo  [WARN] Server slow to start - continuing anyway...
goto OPEN

:READY
echo  [OK] API server is ready

:OPEN
REM Open the LIVE masorah.io site directly (not the local index.html file).
REM The site is static (GitHub Pages, see CNAME) and every page's fetch()
REM calls point at http://localhost:8000 - CORS on the API already allows
REM allow_origins=["*"], so masorah.io works against this local API exactly
REM like the local files did. Local index.html is still on disk as a
REM fallback for offline use (no internet / DNS issues).
echo  [*] Opening https://masorah.io ...
start "" "https://masorah.io"

echo.
echo  ================================================
echo   RUNNING:
echo   API:        http://localhost:8000
echo   API Docs:   http://localhost:8000/docs
echo   Live site:  https://masorah.io   (opened just now)
echo   Local copy: %DIR%index.html      (offline fallback)
echo   Login:      https://masorah.io/login.html
echo   User:       markcorleyjune
echo   Password:   masorah1525
echo.
echo   If the browser did not open, or masorah.io is unreachable,
echo   double-click index.html in this folder instead - it uses the
echo   same local API and works fully offline.
echo  ================================================
echo.
echo  Press any key to STOP the server...
pause >nul

REM Stop
taskkill /f /fi "WINDOWTITLE eq Masorah API*" >nul 2>&1
for /f "tokens=5" %%p in ('netstat -aon 2^>nul ^| findstr /R ":8000 "') do (
    taskkill /f /pid %%p >nul 2>&1
)
echo  [OK] Stopped.
endlocal

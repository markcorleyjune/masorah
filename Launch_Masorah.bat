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
REM masorah.io currently fails TLS validation in the browser
REM (net::ERR_CERT_COMMON_NAME_INVALID) - that is a DNS/certificate
REM problem on the domain/GitHub Pages side, not something this script
REM (or any local file) can fix. Common causes, in order of likelihood:
REM   1. DNS for masorah.io isn't pointed at GitHub Pages' A/AAAA records
REM      (or ALIAS/ANAME at the apex) - something else is answering on
REM      port 443 and presenting an unrelated certificate.
REM   2. A CAA record on masorah.io doesn't allow letsencrypt.org, so
REM      GitHub can't issue the cert at all.
REM   3. The custom domain was only just (re)added in the repo's
REM      Settings -> Pages, and provisioning hasn't finished yet
REM      (can take up to ~1 hour).
REM Fix path: in the GitHub repo -> Settings -> Pages, confirm "Custom
REM domain" is exactly masorah.io, check DNS at the registrar against
REM https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site ,
REM then remove and re-add the custom domain to force re-provisioning if
REM DNS already looks correct.
REM
REM Until that's fixed, probe masorah.io first (curl, bundled with
REM Windows 10 1803+) and fall back to the local copy automatically
REM instead of sending you to a browser security warning every time.
echo  [*] Checking https://masorah.io ...
set "SITE_CODE=000"
where curl >nul 2>&1
if not errorlevel 1 (
    for /f %%c in ('curl -s -o NUL -w "%%{http_code}" --max-time 5 "https://masorah.io" 2^>nul') do set "SITE_CODE=%%c"
)
if "%SITE_CODE%"=="200" (
    echo  [OK] masorah.io is reachable - opening it.
    start "" "https://masorah.io"
) else (
    echo  [WARN] masorah.io not reachable/trusted right now [code: %SITE_CODE%].
    echo  [WARN] This is the ERR_CERT_COMMON_NAME_INVALID DNS/cert issue above -
    echo  [WARN] opening the local copy instead, which uses the same API.
    start "" "%DIR%index.html"
)

echo.
echo  ================================================
echo   RUNNING:
echo   API:        http://localhost:8000
echo   API Docs:   http://localhost:8000/docs
echo   Live site:  https://masorah.io   (opens once the cert/DNS issue above is fixed)
echo   Local copy: %DIR%index.html      (in use now if masorah.io failed the check)
echo   Login:      login.html (same folder as index.html, or masorah.io/login.html once fixed)
echo   User:       markcorleyjune
echo   Password:   masorah1525
echo.
echo   If the browser did not open, double-click index.html in this
echo   folder manually - it uses the same local API and works fully
echo   offline, independent of the masorah.io DNS/cert issue.
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

@echo off
color 0A
echo =======================================================================
echo                 ChessTracker Professional Build Script                 
echo =======================================================================
echo.

echo [STEP 1/5] Validating Local Virtual Environment (.venv)...
if exist ".venv\Scripts\pyinstaller.exe" goto :venv_ok

echo [ERROR] PyInstaller not found in local environment (.venv\Scripts\pyinstaller.exe)
echo Please make sure the local virtual environment .venv is ready.
pause
exit /b 1

:venv_ok
echo [SUCCESS] Local virtual environment (.venv) detected cleanly.
echo.

echo [STEP 2/5] Stopping any running ChessTracker instances...
taskkill /f /im ChessTracker.exe 2>nul
taskkill /f /im "Chess Tracker App.exe" 2>nul
ping 127.0.0.1 -n 2 >nul
echo.

echo [STEP 3/5] Compiling Executable with PyInstaller (Offline Local Build)...
".venv\Scripts\pyinstaller.exe" ^
    --noconfirm ^
    --onedir ^
    --noconsole ^
    --name="ChessTracker" ^
    --icon="src\software\presentation\assets\logo.ico" ^
    --hidden-import="qrcode" ^
    --add-data "src\software\infrastructure\ai;src\software\infrastructure\ai" ^
    --add-data "src\software\infrastructure\persistence\config;src\software\infrastructure\persistence\config" ^
    --add-data "src\software\presentation\assets;src\software\presentation\assets" ^
    --add-data "src\ghostchessmaster\assets;src\ghostchessmaster\assets" ^
    --clean ^
    main.py

if %ERRORLEVEL% neq 0 goto :build_err
echo [SUCCESS] Compilation completed successfully.
echo.

echo [STEP 4/5] Deploying Output Files to Application Directory...
if exist "ChessTracker" rmdir /s /q "ChessTracker"
if exist "Chess Tracker App" rmdir /s /q "Chess Tracker App"

xcopy /e /i /h /y "dist\ChessTracker" "ChessTracker\" >nul

:: Guarantee persistence config directory structure and default JSON files exist in the deployed folder
if not exist "ChessTracker\src\software\infrastructure\persistence\config\saved_games" mkdir "ChessTracker\src\software\infrastructure\persistence\config\saved_games" 2>nul
xcopy /e /i /h /y "src\software\infrastructure\persistence\config\*.json" "ChessTracker\src\software\infrastructure\persistence\config\" >nul 2>&1
echo [SUCCESS] Application files and persistence configuration deployed cleanly.
echo.

echo [STEP 5/5] Cleaning up temporary build artifacts...
if exist "build" rmdir /s /q "build"
if exist "dist" rmdir /s /q "dist"
if exist "ChessTracker.spec" del /f /q "ChessTracker.spec"
if exist "Chess Tracker App.spec" del /f /q "Chess Tracker App.spec"

echo.
echo =======================================================================
echo              BUILD SUCCESSFUL - APPLICATION READY TO RUN                
echo =======================================================================
echo Location: %CD%\ChessTracker\ChessTracker.exe
echo Configuration Persistence: Enabled (JSON auto-saved to config directory)
echo =======================================================================
echo.
exit /b 0

:build_err
echo.
echo [ERROR] PyInstaller build failed with exit code %ERRORLEVEL%
pause
exit /b 1

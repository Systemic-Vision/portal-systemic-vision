@echo off
REM Links Admin Panel - Windows Setup Script

echo.
echo ================================================
echo    Links Admin Panel Setup (Windows)
echo ================================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js is not installed
    echo Please install Node.js 18+ from: https://nodejs.org/
    pause
    exit /b 1
)

echo [OK] Node.js detected: 
node -v

REM Check if npm is installed
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] npm is not installed
    pause
    exit /b 1
)

echo [OK] npm detected:
npm -v
echo.

REM Install dependencies
echo Installing dependencies...
echo This may take a few minutes...
echo.
call npm install

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [OK] Dependencies installed successfully
echo.

REM Check if .env.local exists
if not exist .env.local (
    echo [WARNING] .env.local not found
    echo.
    echo Creating .env.local from template...
    copy .env.example .env.local
    echo [OK] Created .env.local
    echo.
    echo ============================================
    echo IMPORTANT: Configure your environment!
    echo ============================================
    echo.
    echo Edit .env.local and add your Supabase credentials:
    echo   1. Go to https://supabase.com/dashboard
    echo   2. Select your project
    echo   3. Go to Settings ^> API
    echo   4. Copy the values to .env.local
    echo.
    echo Opening .env.local in notepad...
    notepad .env.local
) else (
    echo [OK] .env.local found
)

echo.
echo ================================================
echo    Setup Complete!
echo ================================================
echo.
echo Next steps:
echo   1. Configure .env.local with Supabase credentials
echo   2. Run the database schema in Supabase SQL Editor
echo   3. Create an admin user (see SETUP_GUIDE.md)
echo   4. Start the development server:
echo.
echo      npm run dev
echo.
echo   5. Open http://localhost:3000 in your browser
echo.
echo For detailed instructions, see SETUP_GUIDE.md
echo.
pause

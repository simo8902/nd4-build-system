@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "ENGINE_ROOT=%SCRIPT_DIR%.."
set "BFF_PATH=%SCRIPT_DIR%fbuild.bff"
set "SCRIPT_PATH=%SCRIPT_DIR%build-and-compdb.cmd"
set "DB_PATH=%SCRIPT_DIR%fbuild.windows.fdb"
set "FORCE_CLEAN="
set "TARGET=%~1"

if "%TARGET%"=="" set "TARGET=N4Editor_Debug"

if /I "%TARGET%"=="N4Editor_Debug" goto valid_target
if /I "%TARGET%"=="N4Editor_Release" goto valid_target
if /I "%TARGET%"=="N4Editor_RelWithDebInfo" goto valid_target
if /I "%TARGET%"=="N4Editor" goto valid_target
if /I "%TARGET%"=="N4MapEditor_Debug" goto valid_target
if /I "%TARGET%"=="N4MapEditor_Release" goto valid_target
if /I "%TARGET%"=="N4MapEditor_RelWithDebInfo" goto valid_target
if /I "%TARGET%"=="N4MapEditor" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Debug" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Release" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_RelWithDebInfo" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Package_Debug" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Package_Release" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Package_RelWithDebInfo" goto valid_target
if /I "%TARGET%"=="N4ModelPreviewer_Package" goto valid_target
if /I "%TARGET%"=="all" goto valid_target

echo ERROR: Unsupported build target: %TARGET%
pause
exit /b 2

:valid_target
if not exist "%BFF_PATH%" (
    echo ERROR: BFF file not found: "%BFF_PATH%"
    pause
    exit /b 3
)

set "FBUILD_EXE=C:\sysinternals\FBuild.exe"
if not exist "%FBUILD_EXE%" set "FBUILD_EXE=FBuild.exe"

pushd "%ENGINE_ROOT%" >nul
if errorlevel 1 (
    echo ERROR: Engine directory not found: "%ENGINE_ROOT%"
    pause
    exit /b 3
)

if not exist "%DB_PATH%" (
    set "FORCE_CLEAN=-clean"
) else (
    for /f "usebackq delims=" %%T in (`powershell.exe -NoProfile -Command "((Get-Item -LiteralPath '%BFF_PATH%').LastWriteTimeUtc -gt (Get-Item -LiteralPath '%DB_PATH%').LastWriteTimeUtc) -or ((Get-Item -LiteralPath '%SCRIPT_PATH%').LastWriteTimeUtc -gt (Get-Item -LiteralPath '%DB_PATH%').LastWriteTimeUtc)"`) do if /I "%%T"=="True" set "FORCE_CLEAN=-clean"
)
if defined FORCE_CLEAN echo === Build configuration changed; forcing a clean rebuild ===

echo === Building %TARGET% ===
"%FBUILD_EXE%" %FORCE_CLEAN% -config "%BFF_PATH%" -dbfile "%DB_PATH%" %TARGET%
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" (
    echo ERROR: FBuild failed with exit code %BUILD_EXIT%.
    popd >nul
    pause
    exit /b %BUILD_EXIT%
)

echo === Refreshing compile_commands.json for %TARGET% ===
"%FBUILD_EXE%" -config "%BFF_PATH%" -dbfile "%DB_PATH%" -compdb %TARGET%
set "COMPDB_EXIT=%ERRORLEVEL%"
popd >nul

if not "%COMPDB_EXIT%"=="0" (
    echo ERROR: FBuild compilation database generation failed with exit code %COMPDB_EXIT%.
    pause
    exit /b %COMPDB_EXIT%
)

echo Build and compile database refresh completed successfully.
if /I "%TARGET%"=="N4Editor_Debug" goto launch_editor
if /I "%TARGET%"=="N4Editor" goto launch_editor
goto completed

:launch_editor
set "OUTPUT_EXE=%ENGINE_ROOT%\build-fastbuild\Debug\N4Editor.exe"
if not exist "%OUTPUT_EXE%" (
    echo ERROR: Built executable was not found: "%OUTPUT_EXE%"
    pause
    exit /b 4
)
echo === Launching N4Editor_Debug ===
start "" /D "%ENGINE_ROOT%" "%OUTPUT_EXE%"

:completed
pause
exit /b 0

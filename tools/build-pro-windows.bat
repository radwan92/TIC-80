@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "ROOT_DIR=%%~fI"
set "SCRIPT_NAME=%~nx0"

if not defined BUILD_TYPE set "BUILD_TYPE=MinSizeRel"
if not defined JOBS set "JOBS=%NUMBER_OF_PROCESSORS%"
if not defined JOBS set "JOBS=1"
if not defined BUILD_TOOLCHAIN set "BUILD_TOOLCHAIN=auto"
if not defined BUILD_LANGUAGES set "BUILD_LANGUAGES=all"
if not defined MSVC_ARCH set "MSVC_ARCH=x64"

set "CONFIGURE_ONLY="
set "COLLECT_LANGUAGES="
call :parse_args %*
if errorlevel 1 exit /b 1

call :build_language_args
if errorlevel 1 exit /b 1

where cmake >nul 2>nul
if errorlevel 1 (
    echo error: cmake is not available on PATH 1>&2
    exit /b 1
)

call :require_language_tools
if errorlevel 1 exit /b 1

if /I "%BUILD_TOOLCHAIN%"=="msvc" (
    call :run_msvc
    exit /b %ERRORLEVEL%
)

if /I "%BUILD_TOOLCHAIN%"=="mingw" (
    call :run_mingw
    exit /b %ERRORLEVEL%
)

if /I not "%BUILD_TOOLCHAIN%"=="auto" (
    echo error: BUILD_TOOLCHAIN must be auto, msvc, or mingw. 1>&2
    exit /b 1
)

set "MSVC_CONFIGURED="
call :run_msvc
if not errorlevel 1 exit /b 0
if defined MSVC_CONFIGURED exit /b %ERRORLEVEL%

echo.
echo warning: MSVC build path failed; falling back to MinGW. 1>&2
call :run_mingw
exit /b %ERRORLEVEL%

:run_msvc
call :detect_msvc_generator
if not defined MSVC_GENERATOR (
    echo error: no Visual Studio C++ toolchain was found. 1>&2
    exit /b 1
)

call :select_build_dir msvc
call :prepare_build_dir
if errorlevel 1 exit /b 1
if not exist "%ACTIVE_BUILD_DIR%" mkdir "%ACTIVE_BUILD_DIR%"

echo Configuring TIC-80 PRO for Windows with MSVC:
echo   Generator: %MSVC_GENERATOR%
echo   Platform:  %MSVC_ARCH%
echo   Build dir: %ACTIVE_BUILD_DIR%
echo   Languages: %LANGUAGE_LABEL%
echo.

if defined MSVC_TOOLSET (
    cmake ^
        -S "%ROOT_DIR%" ^
        -B "%ACTIVE_BUILD_DIR%" ^
        -G "%MSVC_GENERATOR%" ^
        -A "%MSVC_ARCH%" ^
        -T "%MSVC_TOOLSET%" ^
        "-DCMAKE_BUILD_TYPE=%BUILD_TYPE%" ^
        -DBUILD_SDLGPU=On ^
        %LANGUAGE_CMAKE_ARGS% ^
        -DBUILD_PRO=On ^
        -DCMAKE_EXPORT_COMPILE_COMMANDS=On
) else (
    cmake ^
        -S "%ROOT_DIR%" ^
        -B "%ACTIVE_BUILD_DIR%" ^
        -G "%MSVC_GENERATOR%" ^
        -A "%MSVC_ARCH%" ^
        "-DCMAKE_BUILD_TYPE=%BUILD_TYPE%" ^
        -DBUILD_SDLGPU=On ^
        %LANGUAGE_CMAKE_ARGS% ^
        -DBUILD_PRO=On ^
        -DCMAKE_EXPORT_COMPILE_COMMANDS=On
)
if errorlevel 1 exit /b 1
set "MSVC_CONFIGURED=1"

if defined CONFIGURE_ONLY (
    echo.
    echo Configured TIC-80 PRO for Windows with MSVC. Build files are under:
    echo   %ACTIVE_BUILD_DIR%
    exit /b 0
)

cmake --build "%ACTIVE_BUILD_DIR%" --config "%BUILD_TYPE%" --parallel "%JOBS%"
if errorlevel 1 exit /b 1

echo.
echo Built TIC-80 PRO for Windows with MSVC. Binary output should be under:
echo   %ACTIVE_BUILD_DIR%\bin
exit /b 0

:run_mingw
where mingw32-make >nul 2>nul
if errorlevel 1 (
    echo error: mingw32-make is not available on PATH 1>&2
    echo Add the MSYS2 MinGW bin directory to PATH, for example: 1>&2
    echo   C:\Ruby27-x64\msys64\mingw64\bin 1>&2
    exit /b 1
)

call :select_build_dir mingw
call :prepare_build_dir
if errorlevel 1 exit /b 1
if not exist "%ACTIVE_BUILD_DIR%" mkdir "%ACTIVE_BUILD_DIR%"

echo Configuring TIC-80 PRO for Windows with MinGW:
echo   Generator: MinGW Makefiles
echo   Build dir: %ACTIVE_BUILD_DIR%
echo   Languages: %LANGUAGE_LABEL%
echo.

cmake ^
    -S "%ROOT_DIR%" ^
    -B "%ACTIVE_BUILD_DIR%" ^
    -G "MinGW Makefiles" ^
    "-DCMAKE_BUILD_TYPE=%BUILD_TYPE%" ^
    -DBUILD_SDLGPU=On ^
    %LANGUAGE_CMAKE_ARGS% ^
    -DBUILD_PRO=On ^
    -DCMAKE_EXPORT_COMPILE_COMMANDS=On
if errorlevel 1 exit /b 1

if defined CONFIGURE_ONLY (
    echo.
    echo Configured TIC-80 PRO for Windows with MinGW. Build files are under:
    echo   %ACTIVE_BUILD_DIR%
    exit /b 0
)

cmake --build "%ACTIVE_BUILD_DIR%" --parallel "%JOBS%"
if errorlevel 1 exit /b 1

echo.
echo Built TIC-80 PRO for Windows with MinGW. Binary output should be under:
echo   %ACTIVE_BUILD_DIR%\bin
exit /b 0

:detect_msvc_generator
if defined MSVC_GENERATOR exit /b 0

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq tokens=1 delims=." %%V in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion 2^>nul`) do set "VS_MAJOR=%%V"
)

if "%VS_MAJOR%"=="18" set "MSVC_GENERATOR=Visual Studio 18 2026"
if "%VS_MAJOR%"=="17" set "MSVC_GENERATOR=Visual Studio 17 2022"
if "%VS_MAJOR%"=="16" set "MSVC_GENERATOR=Visual Studio 16 2019"
if "%VS_MAJOR%"=="15" set "MSVC_GENERATOR=Visual Studio 15 2017"

if defined MSVC_GENERATOR exit /b 0

cmake --help | findstr /C:"Visual Studio 17 2022" >nul
if not errorlevel 1 set "MSVC_GENERATOR=Visual Studio 17 2022"
if defined MSVC_GENERATOR exit /b 0

cmake --help | findstr /C:"Visual Studio 16 2019" >nul
if not errorlevel 1 set "MSVC_GENERATOR=Visual Studio 16 2019"
exit /b 0

:parse_args
if "%~1"=="" exit /b 0

set "ARG=%~1"
if /I "!ARG!"=="--configure-only" (
    set "CONFIGURE_ONLY=1"
    shift
    goto parse_args
)
if /I "!ARG!"=="--msvc" (
    set "BUILD_TOOLCHAIN=msvc"
    shift
    goto parse_args
)
if /I "!ARG!"=="--mingw" (
    set "BUILD_TOOLCHAIN=mingw"
    shift
    goto parse_args
)
if /I "!ARG:~0,12!"=="--languages=" (
    set "BUILD_LANGUAGES=!ARG:~12!"
    shift
    goto parse_args
)
if /I "!ARG!"=="--languages" (
    if "%~2"=="" (
        echo error: --languages requires a comma-separated value, for example lua,python. 1>&2
        exit /b 1
    )
    set "BUILD_LANGUAGES=%~2"
    set "COLLECT_LANGUAGES=1"
    shift
    shift
    goto parse_args
)

if defined COLLECT_LANGUAGES (
    set "BUILD_LANGUAGES=!BUILD_LANGUAGES!,%~1"
    shift
    goto parse_args
)

echo error: unknown argument: %~1 1>&2
echo usage: %SCRIPT_NAME% [--msvc^|--mingw] [--configure-only] [--languages all^|lua,python,...] 1>&2
exit /b 1

:build_language_args
set "LANGUAGE_LABEL=%BUILD_LANGUAGES%"
set "LANGUAGE_ALL="
set "LANGUAGE_SELECTED="
set "LANG_LUA=Off"
set "LANG_MOON=Off"
set "LANG_YUE=Off"
set "LANG_FENNEL=Off"
set "LANG_WREN=Off"
set "LANG_RUBY=Off"
set "LANG_WASM=Off"
set "LANG_SCHEME=Off"
set "LANG_SQUIRREL=Off"
set "LANG_PYTHON=Off"
set "LANG_JS=Off"
set "LANG_JANET=Off"

if /I "%BUILD_LANGUAGES%"=="all" (
    set "LANGUAGE_ALL=1"
    set "LANGUAGE_LABEL=all"
    set "LANGUAGE_CMAKE_ARGS=-DBUILD_WITH_ALL=On"
    set "LANG_RUBY=On"
    exit /b 0
)

set "LANGUAGE_LIST=%BUILD_LANGUAGES:,= %"
for %%L in (%LANGUAGE_LIST%) do (
    call :enable_language "%%~L"
    if errorlevel 1 exit /b 1
)

if not defined LANGUAGE_SELECTED (
    echo error: --languages must include at least one language or "all". 1>&2
    exit /b 1
)

set "LANGUAGE_CMAKE_ARGS=-DBUILD_WITH_ALL=Off -DBUILD_WITH_LUA=%LANG_LUA% -DBUILD_WITH_MOON=%LANG_MOON% -DBUILD_WITH_YUE=%LANG_YUE% -DBUILD_WITH_FENNEL=%LANG_FENNEL% -DBUILD_WITH_WREN=%LANG_WREN% -DBUILD_WITH_RUBY=%LANG_RUBY% -DBUILD_WITH_WASM=%LANG_WASM% -DBUILD_WITH_SCHEME=%LANG_SCHEME% -DBUILD_WITH_SQUIRREL=%LANG_SQUIRREL% -DBUILD_WITH_PYTHON=%LANG_PYTHON% -DBUILD_WITH_JS=%LANG_JS% -DBUILD_WITH_JANET=%LANG_JANET%"
exit /b 0

:enable_language
set "LANGUAGE_SELECTED=1"
if /I "%~1"=="lua" (
    set "LANG_LUA=On"
    exit /b 0
)
if /I "%~1"=="moon" (
    set "LANG_MOON=On"
    exit /b 0
)
if /I "%~1"=="yue" (
    set "LANG_YUE=On"
    exit /b 0
)
if /I "%~1"=="fennel" (
    set "LANG_FENNEL=On"
    exit /b 0
)
if /I "%~1"=="wren" (
    set "LANG_WREN=On"
    exit /b 0
)
if /I "%~1"=="ruby" (
    set "LANG_RUBY=On"
    exit /b 0
)
if /I "%~1"=="wasm" (
    set "LANG_WASM=On"
    exit /b 0
)
if /I "%~1"=="scheme" (
    set "LANG_SCHEME=On"
    exit /b 0
)
if /I "%~1"=="squirrel" (
    set "LANG_SQUIRREL=On"
    exit /b 0
)
if /I "%~1"=="python" (
    set "LANG_PYTHON=On"
    exit /b 0
)
if /I "%~1"=="js" (
    set "LANG_JS=On"
    exit /b 0
)
if /I "%~1"=="janet" (
    set "LANG_JANET=On"
    exit /b 0
)

echo error: unknown language: %~1 1>&2
echo supported languages: all,lua,moon,yue,fennel,wren,ruby,wasm,scheme,squirrel,python,js,janet 1>&2
exit /b 1

:select_build_dir
if defined BUILD_DIR (
    set "ACTIVE_BUILD_DIR=%BUILD_DIR%"
) else (
    set "ACTIVE_BUILD_DIR=%ROOT_DIR%\out\build-pro-windows\%~1"
)
exit /b 0

:prepare_build_dir
if not exist "%ACTIVE_BUILD_DIR%\CMakeCache.txt" exit /b 0

set "CACHE_HOME="
for /f "tokens=1,* delims==" %%A in ('findstr /B /C:"CMAKE_HOME_DIRECTORY:INTERNAL=" "%ACTIVE_BUILD_DIR%\CMakeCache.txt" 2^>nul') do set "CACHE_HOME=%%B"
if not defined CACHE_HOME exit /b 0

set "CACHE_HOME_NORM=!CACHE_HOME:/=\!"
if /I "!CACHE_HOME_NORM!"=="%ROOT_DIR%" exit /b 0

if defined BUILD_DIR (
    echo error: BUILD_DIR contains a CMake cache for a different source directory: !CACHE_HOME! 1>&2
    echo Delete or choose a different BUILD_DIR before building from: %ROOT_DIR% 1>&2
    exit /b 1
)

echo warning: removing stale CMake build directory: %ACTIVE_BUILD_DIR% 1>&2
echo          cache was created for: !CACHE_HOME! 1>&2
cmake -E rm -rf "%ACTIVE_BUILD_DIR%"
exit /b %ERRORLEVEL%

:require_language_tools
if not defined LANGUAGE_ALL if /I not "%LANG_RUBY%"=="On" exit /b 0

call :add_common_tool_paths

where ruby >nul 2>nul
if errorlevel 1 (
    echo error: ruby is not available on PATH. 1>&2
    echo Ruby/mruby support requires Ruby+Devkit or Ruby's bin directory on PATH. 1>&2
    echo README.md suggests Ruby+Devkit 2.7.8, for example: 1>&2
    echo   C:\Ruby27-x64\bin 1>&2
    exit /b 1
)

where rake >nul 2>nul
if errorlevel 1 (
    echo error: rake is not available on PATH. 1>&2
    echo Ruby/mruby support builds through rake. 1>&2
    echo Install Ruby+Devkit with rake, or add Ruby's bin directory to PATH. 1>&2
    exit /b 1
)

where gcc >nul 2>nul
if errorlevel 1 (
    echo error: gcc is not available on PATH. 1>&2
    echo Ruby/mruby support uses the Ruby+Devkit MinGW compiler for host tools. 1>&2
    echo Add the MSYS2 MinGW bin directory to PATH, for example: 1>&2
    echo   C:\Ruby27-x64\msys64\mingw64\bin 1>&2
    exit /b 1
)

exit /b 0

:add_common_tool_paths
for %%D in (
    "%SystemDrive%\Ruby34-x64\bin"
    "%SystemDrive%\Ruby34-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby33-x64\bin"
    "%SystemDrive%\Ruby33-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby32-x64\bin"
    "%SystemDrive%\Ruby32-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby31-x64\bin"
    "%SystemDrive%\Ruby31-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby30-x64\bin"
    "%SystemDrive%\Ruby30-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby27-x64\bin"
    "%SystemDrive%\Ruby27-x64\msys64\mingw64\bin"
    "%SystemDrive%\Ruby27\bin"
    "%SystemDrive%\Ruby27\msys32\mingw32\bin"
) do (
    if exist "%%~D" call set "PATH=%%~D;%%PATH%%"
)
exit /b 0

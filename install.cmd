@ECHO OFF
:: don't leak env variables into the calling interpreter...
setlocal
:: better defaults for dealing with quotes...
:: You need to escape ! afterwards with ^^! or "^!"
SETLOCAL enabledelayedexpansion

:: Made True to Log Files Installation 
SET DEBUG="true"

:: A comment on quotes around file path variables:
:: only add quotes around the variable when you use the variable
:: as a file path (exists, type, pipe,...) and the parenthesis of a
:: for, not when used as a string (-> setting variables)

:: more does not work if the codepage is set to unicode 65001
for /F "tokens=*" %%F in ('chcp') do (
    for %%A in (%%F) do (set _last=%%A)
)
SET CP=%_last:~0%
if "!CP:~-1!"=="." (
    SET CP=!CP:~0,-1!
)
chcp 850 > NUL
:: echo %CP%

:: not so sane default...
SET PREFIX=C:\SCM\PortableGit\mingw64

:: find a git.exe in path and use that as a default dir
where /Q git.exe
if errorlevel 1 goto :defaultpath

for /F "delims=" %%F in ('where git.exe') do (
    set bindir=%%~dpF
    rem break after the first, so that we get the first in path
    goto :break
)
goto :defaultpath

:break
rem remove the last slash
SET bindir=%bindir:~0,-1%
for %%G in ("%bindir%") do set installdir=%%~dpG
set PREFIX=%installdir%mingw64
goto :foundprefix

:defaultpath
:: default for Git for Windows 2.x
if exist "%ProgramFiles%\Git" (
    set PREFIX=%ProgramFiles%\Git\mingw64
)

:foundprefix
:: overwrite with whatever the user supplied...
IF NOT "%~1"=="" (
    REM make it easier for the user to specify a prefix:
    REM just supplying the git dir is enough...
    if exist "%~1\mingw64" (
        set PREFIX=%~1\mingw64
    ) else (
        echo Using git install path "%~1" as PREFIX, please make sure it's really a
        echo path to the mingw64 directory...
        echo.
        SET PREFIX=%~1
    )
)
:: remove a trailing slash, but only after removing quotes...
set PREFIX=!PREFIX:"=!
IF %PREFIX:~-1%==\ SET PREFIX=%PREFIX:~0,-1%

for %%H in ("%PREFIX%") do set GIT_INSTALL_DIR=%%~dpH

set GIT_INSTALL_DIR=!GIT_INSTALL_DIR:"=!
IF %GIT_INSTALL_DIR:~-1%==\ SET GIT_INSTALL_DIR=%GIT_INSTALL_DIR:~0,-1%

if not exist "%GIT_INSTALL_DIR%\mingw64" (
    echo No mingw64 folder found in %GIT_INSTALL_DIR%.
    echo.
    echo Please supply a proper "Git for Windows 2.x" install path:
    echo "install.cmd c:\[git-install-path]"
    set ERROR=1
    goto :exit
)

echo Installing to %PREFIX%
SET HTMLDIR=%PREFIX%\share\doc\git-doc
SET GITEXTRAS=%~dp0

:: Remove Trailing Slash from Location of Installers
IF %GITEXTRAS:~-1%==\ SET GITEXTRAS=%GITEXTRAS:~0,-1%

IF NOT EXIST "%PREFIX%\bin" MKDIR "%PREFIX%\bin"

:: Check that we can install into that dir or need admin rights...
set _testfile=%PREFIX%\bin\testfile_to_check_if_dir_is_writeable-577423947123.~
copy NUL "%_testfile%" >NUL 2>&1
IF EXIST "%_testfile%" (
    set IS_WRITEABLE=yes
    del "%_testfile%"
) else (
    set IS_WRITEABLE=no
)
if "%IS_WRITEABLE%"=="no" (
    echo.
    echo Directory for binaries ["%PREFIX%\bin"] is not writeable by install.cmd.
    echo.
    echo You probably need to run install.cmd from an admin prompt.
    set ERROR=1
    goto :exit
)

SET COMMANDS_WITHOUT_REPO=git-alias git-extras git-fork git-setup

:: Modified Comment to Show Source folder
ECHO Installing binaries [SRC: %GITEXTRAS%]...

:: Deleting Existing Files Before Rebuild
FOR /R "%GITEXTRAS%\bin" %%i in (*.*) DO (
    IF EXIST "%PREFIX%\bin\%%~ni" (
        IF %DEBUG%=="true" ( ECHO "DEL: %PREFIX%\bin\%%~ni ..." )
        DEL /F /Q "%PREFIX%\bin\%%~ni"
    )
)
:: Deleting Existing Files Before Rebuild
FOR %%i in (%COMMANDS_WITHOUT_REPO%) DO (
    IF EXIST "%PREFIX%\bin\%%i" (
        IF %DEBUG%=="true" ( ECHO "DEL: %PREFIX%\bin\%%i ..." )
        DEL /F /Q "%PREFIX%\bin\%%i"
    )
)

FOR /R "%GITEXTRAS%\bin" %%i in (*.*) DO (
::  Fixation for Windows 10.0.17134 Build 17134 (Won't install without /E)    
::  Echo file being written for testing
    IF %DEBUG%=="true" ( ECHO "Write #1: %PREFIX%\bin\%%~ni" )
    ECHO  + Header
    ECHO #^^!/usr/bin/env bash > "%PREFIX%\bin\%%~ni"
    ECHO  + helper\reset-env
    TYPE "%GITEXTRAS%\helper\reset-env" >> "%PREFIX%\bin\%%~ni"
    ECHO  + helper\git-extra-utility
    TYPE "%GITEXTRAS%\helper\git-extra-utility" >> "%PREFIX%\bin\%%~ni"
    ECHO  + helper\is-git-repo
    TYPE "%GITEXTRAS%\helper\is-git-repo" >> "%PREFIX%\bin\%%~ni"
    
    
    :: Added /E Option for Installation Fix On Windows 10 Higher Version
    ECHO  + %GITEXTRAS%\bin\%%~ni
    MORE /E +2 "%GITEXTRAS%\bin\%%~ni" >> "%PREFIX%\bin\%%~ni"
    ECHO.
)

FOR %%i in (%COMMANDS_WITHOUT_REPO%) DO (
::  Fixation for Windows 10.0.17134 Build 17134 (Won't install without /E) 
::  Echo file being written for testing
    IF %DEBUG%=="true" ( ECHO "Write #2: %PREFIX%\bin\%%i" )

    ECHO  + Header
    ECHO #^^!/usr/bin/env bash > "%PREFIX%\bin\%%i"
    ECHO  + helper\reset-env
    TYPE "%GITEXTRAS%\helper\reset-env" >> "%PREFIX%\bin\%%i"
    ECHO  + helper\git-extra-utility
    TYPE "%GITEXTRAS%\helper\git-extra-utility" >> "%PREFIX%\bin\%%i"
    
    ::  Added /E Option for Installation Fix On Windows 10 Higher Version
    ECHO  + %GITEXTRAS%\bin\%%i
    MORE /E +2 "%GITEXTRAS%\bin\%%i" >> "%PREFIX%\bin\%%i"
    ECHO.
)

echo Installing man pages...
set _QUIET=/NP /NFL /NDL /NJS /NJH
ROBOCOPY %_QUIET% /IS "%GITEXTRAS%\man" "%HTMLDIR%" *.html
IF %ERRORLEVEL% GTR 7 (
    echo Not all html docs could be copied to "%GITEXTRAS%\man".
    echo.
    echo You probably need to run the install.cmd script from an admin prompt.
    set ERROR=1
    goto :exit
)
echo done

if not exist "%GIT_INSTALL_DIR%\usr\bin\column.exe" (
    where /Q column.exe
    if errorlevel 1 (
        echo.
        echo column.exe is missing: Not in "%GIT_INSTALL_DIR%\usr\bin" or in PATH!
        echo.
        echo "git summary", "git summary-line" and "git ignore-io" do not work without.
        echo If you need these commands, please install Git for Windows > 2.7.0.
        echo.
    )
)


:exit
:: Sync Unflushed File Buffers
sync.exe c:

:: Actual Code to From Original
@chcp %CP% > NUL
@endlocal enabledelayedexpansion
@endlocal
@exit /b %ERROR%

@echo off
rem Dev/CI shim: run the RelayPilot CLI through the system racket.
setlocal
set "REPO=%~dp0.."
racket "%REPO%\app\cli.rkt" %*
exit /b %ERRORLEVEL%

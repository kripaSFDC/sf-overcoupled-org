@echo off
REM ============================================================
REM  W02 demo driver - paced terminal B-roll for recording
REM  Usage:  demo.bat break | prove | test | reset | all
REM
REM  Run from the project root. Start OBS, then run this.
REM  Nothing here is typed by hand on camera.
REM ============================================================

set "PROMPT_TEXT=sf-overcoupled-org>"

title sf-overcoupled-org
color 0F
mode con: cols=120 lines=30

if "%~1"=="" goto :usage
if /i "%~1"=="break" goto :break
if /i "%~1"=="prove" goto :prove
if /i "%~1"=="test"  goto :test
if /i "%~1"=="reset" goto :reset
if /i "%~1"=="all"   goto :all
goto :usage

REM ------------------------------------------------------------ shots

:break
cls
call :hold 2
call :type "sf apex run -f scripts\apex\02-break-it.apex"
call :hold 1
sf apex run -f scripts\apex\02-break-it.apex
call :hold 6
goto :eof

:prove
cls
call :hold 2
call :type "sf apex run -f scripts\apex\03-prove-it.apex"
call :hold 1
sf apex run -f scripts\apex\03-prove-it.apex
call :hold 6
goto :eof

:test
cls
call :hold 2
call :type "sf apex run test -t BulkSafetyTest -w 20 -r human"
call :hold 1
sf apex run test -t BulkSafetyTest -w 20 -r human
call :hold 6
goto :eof

:reset
REM off-camera housekeeping between takes
cls
echo Resetting demo data...
sf apex run -f scripts\apex\00-reset.apex
sf apex run -f scripts\apex\01-seed.apex
echo.
echo Reset complete. Ready for the next take.
goto :eof

:all
call :break
call :hold 3
call :prove
goto :eof

REM ------------------------------------------------------------ helpers

:type
REM types the command one character at a time, at a human-ish rhythm
powershell -NoProfile -Command "$p='%PROMPT_TEXT%'; $t='%~1'; Write-Host -NoNewline ($p + ' '); foreach($c in $t.ToCharArray()){ Write-Host -NoNewline ([string]$c); Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 95) }; Write-Host ''"
goto :eof

:hold
powershell -NoProfile -Command "Start-Sleep -Seconds %~1"
goto :eof

:usage
echo.
echo   demo.bat break   - runs 02-break-it, dies at SOQL 101
echo   demo.bat prove   - runs 03-prove-it, prints Queries used: 0 / 100
echo   demo.bat test    - runs BulkSafetyTest
echo   demo.bat reset   - wipes and reseeds between takes (do this OFF camera)
echo   demo.bat all     - break then prove, back to back
echo.
goto :eof
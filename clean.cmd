@echo off
cd /d "%~dp0"

for /d %%i in (.dist) do (
  if exist "%%i" (
    echo Deleting %%i
    rd /s /q "%%i"
  )
)

for /d /r %%i in (backup lib) do (
  if exist "%%i" (
    echo Deleting %%i
    rd /s /q "%%i"
  )
)

for /r %%i in (*.compiled *.dbg *.exe *.o *.ppu *.res *.rst) do (
  if exist "%%i" (
    echo Deleting %%i
    del /f /q "%%i"
  )
)

for /f "delims=" %%d in ('dir /s /b /ad ^| findstr /vi "\\.git\\" ^| sort /r') do (
  dir /b "%%d" | findstr /r . >nul 2>nul || (
    echo Deleting %%d
    rd "%%d"
  )
)

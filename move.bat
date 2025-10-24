@echo off
set "source_dir=D:\Andorid\WORK\fongmi-media\libraries"
set "target_dir=C:\Users\wokee\Documents\TV\app\libs"
set "move_list=D:\Andorid\WORK\fongmi-media\move.txt"

for /r "%source_dir%" %%a in (lib-*-release.aar) do (
    findstr /x /c:"%%~nxa" "%move_list%" >nul
    if not errorlevel 1 (
        copy "%%a" "%target_dir%\"
        echo Moved "%%a" to "%target_dir%"
    ) else (
        echo Skipped "%%a" as it is not listed in move.txt
    )
)
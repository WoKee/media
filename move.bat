@echo off
chcp 65001 >nul
set "source_dir=D:\\AndroidStudioProjects\media\libraries"
set "target_dir=D:\AndroidStudioProjects\TV-MS\app\libs"
set "move_list=D:\\AndroidStudioProjects\media\move.txt"

for /r "%source_dir%" %%a in (lib-*-release.aar) do (
    findstr /x /c:"%%~nxa" "%move_list%" >nul
    if not errorlevel 1 (
        copy "%%a" "%target_dir%\" >nul
        echo Moved "%%a" to "%target_dir%"
    )
)
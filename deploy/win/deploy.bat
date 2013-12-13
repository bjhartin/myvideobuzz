setlocal ENABLEDELAYEDEXPANSION
REM the %~dp0 variable represents the location of this batch file, so if you'd like to drop the latest zip into the same folder as the batch
REM when you'd like to update your Rokus, you can set your ZIP_LOCATION variable like this:
REM set ZIP_LOCATION=%~dp0\myvideobuzz.zip
REM Then when it comes to a new release, you can just drop the zip file into the same directory as the batch file, and run it
set ZIP_LOCATION=%~dp0..\..\myvideobuzz.zip
for /F "eol=; tokens=1,2" %%i in (..\rokus.txt) do (
    @echo Roku: %%i
    @echo Pass: %%j
    REM Determine if authentication is required
    curl --silent --connect-timeout 10 --write-out "%%{http_code}" %%i > %~dp0\tmp.txt
    set /p HTTPSTATUS=<%~dp0\tmp.txt
    del %~dp0\tmp.txt
    REM 401 means authentication required
    IF !HTTPSTATUS!==401 (
        curl --connect-timeout 10 --user %%j --digest -s -S -F "mysubmit=Install" -F "archive=@%ZIP_LOCATION%" -F "passwd=" http://%%i/plugin_install > %~dp0\%%i.txt
    ) ELSE (
        curl --connect-timeout 10 -s -S -F "mysubmit=Install" -F "archive=@%ZIP_LOCATION%" -F "passwd=" http://%%i/plugin_install > %~dp0\%%i.txt
    )
    REM print the result
    findstr /C:"<font color=\"red\">" %~dp0\%%i.txt
    del %~dp0\%%i.txt
)
PAUSE
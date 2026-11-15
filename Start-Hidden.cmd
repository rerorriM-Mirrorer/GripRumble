@echo off
pushd "%~dp0" || exit /b 1
py -3 launch_hidden.py >> "launcher.log" 2>&1
set "grip_exit=%errorlevel%"
popd
exit /b %grip_exit%

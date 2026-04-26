@echo off
title 배드민턴 협회 앱 실행
color 0B

cd /d "%~dp0"

echo.
echo ========================================
echo   배드민턴 협회 앱 실행 중...
echo ========================================
echo.

call flutter pub get

echo.
echo  Chrome 창을 엽니다...
start "Chrome" cmd /c "cd /d %~dp0 && flutter run -d chrome"

echo  휴대폰에 설치합니다 (Samsung SM)...
echo  (휴대폰이 USB로 연결되어 있어야 합니다)
echo.

flutter run -d SM

pause

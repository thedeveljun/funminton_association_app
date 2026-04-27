@echo off
chcp 65001 >nul
title 배드민턴 협회 앱 실행
color 0B

cd /d "%~dp0"

echo.
echo ========================================
echo   배드민턴 협회 앱 - 동시 실행 모드
echo ========================================
echo.
echo   [1/3] 패키지 설치 확인 중...
call flutter pub get
echo.

echo   [2/3] Chrome 창을 새로 엽니다...
start "Funminton-Chrome" cmd /k "color 0E && title 컴퓨터(Chrome) - r=핫리로드, q=종료 && cd /d %~dp0 && flutter run -d chrome"

timeout /t 3 /nobreak >nul

echo   [3/3] 휴대폰(Samsung SM)에 설치합니다...
echo.
echo   ========================================
echo   ※ 코드 수정 후 r 키 누르면 즉시 반영
echo   ※ q 키 누르면 종료
echo   ========================================
echo.

start "Funminton-Phone" cmd /k "color 0A && title 휴대폰(Samsung SM) - r=핫리로드, q=종료 && cd /d %~dp0 && flutter run -d SM"

timeout /t 2 /nobreak >nul

echo.
echo   두 창이 모두 열렸습니다!
echo.
echo   - 노란색 창: Chrome (컴퓨터)
echo   - 초록색 창: 휴대폰 (Samsung)
echo.
echo   각 창에서 r 키를 누르면 코드 변경사항이 즉시 반영됩니다.
echo.
echo   이 창은 닫으셔도 됩니다.
echo.
pause
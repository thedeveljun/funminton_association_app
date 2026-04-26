🏸 배드민턴 협회 관리 앱
Flutter 기반 배드민턴 협회 통합 관리 앱입니다.
설치 및 실행
1. 패키지 설치
```bash
flutter pub get
```
2. 앱 실행
```bash
flutter run
```
3. APK 빌드
```bash
flutter build apk --release
# 결과물: build/app/outputs/flutter-apk/app-release.apk
```
파일 구조
```
lib/
├── main.dart                          ← 앱 진입점
├── core/theme/
│   ├── app_colors.dart                ← 색상 상수
│   └── app_theme.dart                 ← 테마 설정
├── models/
│   ├── club.dart                      ← 클럽 모델
│   ├── player.dart                    ← 선수 모델
│   ├── tournament.dart                ← 대회 모델
│   ├── match_game.dart                ← 경기 모델
│   └── finance_transaction.dart       ← 재정 모델
├── services/
│   └── sample_data.dart               ← 샘플 데이터
├── widgets/common/
│   ├── app_badge.dart                 ← 뱃지 위젯
│   ├── section_header.dart            ← 섹션 헤더
│   ├── filter_chips.dart              ← 필터 칩 행
│   └── stat_banner.dart               ← 통계 배너
└── screens/
    ├── home/home_screen.dart          ← 홈 화면
    ├── clubs/                         ← 클럽 관리
    ├── players/                       ← 선수 관리
    ├── tournaments/                   ← 대회 운영
    ├── finance/                       ← 재정 관리
    ├── rankings/                      ← 랭킹
    └── admin/                         ← 협회 행정
```
화면 목록
화면	기능
홈	협회 통계, 메뉴 그리드, 최근 활동
클럽관리	클럽 목록/상세/등록, 회장·총무 정보, 협회비 납부 현황
선수관리	선수 목록/상세/등록, 급수·연령대 필터
대회운영	진행중·예정·완료 탭, 대회 등록 폼
재정관리	수입/지출 내역, 클럽별 협회비 납부, 요약
랭킹	급수·성별 필터, 포인트 순위
협회행정	공지사항, 이사회 일정, 공문

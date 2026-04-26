import 'package:flutter/material.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
///  배드민턴 협회 디자인 시스템
///  주조색: 딥 네이비(#0F2557) — 신뢰·권위
///  포인트: 로열 블루(#1E4FC2) + 미드나잇(#162040)
///  배경:   라이트 그레이(#F4F6FA)
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AppColors {
  AppColors._();

  // ── 메인 ──────────────────────────────────
  static const Color primary = Color(0xFF0F2557); // 딥 네이비
  static const Color primaryDark = Color(0xFF162040); // 미드나잇
  static const Color primaryMid = Color(0xFF1E4FC2); // 로열 블루
  static const Color primaryLight = Color(0xFFE8EFFE); // 라이트 블루

  // 기존 호환용 alias
  static const Color blue = Color(0xFF0F2557);
  static const Color blue2 = Color(0xFF1E4FC2);
  static const Color blue3 = Color(0xFFE8EFFE);
  static const Color blueDark = Color(0xFF162040);

  // ── 성공·그린 ─────────────────────────────
  static const Color green = Color(0xFF1A6B3C);
  static const Color green2 = Color(0xFF27AE60);
  static const Color green3 = Color(0xFFD4EDDA);

  // ── 경고·레드 ─────────────────────────────
  static const Color red = Color(0xFFB91C1C);
  static const Color red2 = Color(0xFFDC2626);
  static const Color red3 = Color(0xFFFEE2E2);

  // ── 주의·앰버 ─────────────────────────────
  static const Color amber = Color(0xFF92400E);
  static const Color amber2 = Color(0xFFFEF3C7);
  static const Color amberText = Color(0xFF78350F);

  // ── 퍼플 ──────────────────────────────────
  static const Color purple = Color(0xFF4C1D95);
  static const Color purple2 = Color(0xFFEDE9FE);
  static const Color purpleText = Color(0xFF3B0764);

  // ── 배경·서피스 ───────────────────────────
  static const Color bg = Color(0xFFF4F6FA); // 페이지 배경
  static const Color surface = Color(0xFFFFFFFF); // 카드 배경
  static const Color surfaceAlt = Color(0xFFF8F9FC); // 보조 배경

  // 기존 호환용
  static const Color gray = Color(0xFFF4F6FA);
  static const Color gray2 = Color(0xFFE4E8F0);
  static const Color gray3 = Color(0xFF9BA8BB);

  // ── 텍스트 ────────────────────────────────
  static const Color text = Color(0xFF0D1B3E); // 제목
  static const Color text2 = Color(0xFF374151); // 본문
  static const Color muted = Color(0xFF6B7A99); // 보조

  // ── 구분선 ────────────────────────────────
  static const Color divider = Color(0xFFE4E8F0);
  static const Color white = Color(0xFFFFFFFF);

  // ── 급수 색상 ─────────────────────────────
  // 자강조(최고) → 초심조(입문) 순서
  static Color gradeBackground(String grade) {
    switch (grade) {
      case '자강조':
        return const Color(0xFF0F2557); // 딥 네이비
      case 'S조':
        return const Color(0xFF1E4FC2); // 로열 블루
      case 'A조':
        return const Color(0xFF1A6B3C); // 딥 그린
      case 'B조':
        return const Color(0xFF0E7490); // 틸
      case 'C조':
        return const Color(0xFF92400E); // 앰버 다크
      case 'D조':
        return const Color(0xFF6D28D9); // 퍼플
      case '초심조':
        return const Color(0xFF9BA8BB); // 그레이
      default:
        return const Color(0xFFE4E8F0);
    }
  }

  static Color gradeText(String grade) => const Color(0xFFFFFFFF);

  static Color gradeLightBg(String grade) {
    switch (grade) {
      case '자강조':
        return const Color(0xFFE8EFFE);
      case 'S조':
        return const Color(0xFFDBEAFE);
      case 'A조':
        return const Color(0xFFD4EDDA);
      case 'B조':
        return const Color(0xFFCCFBF1);
      case 'C조':
        return const Color(0xFFFEF3C7);
      case 'D조':
        return const Color(0xFFEDE9FE);
      case '초심조':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static Color gradeLightText(String grade) {
    switch (grade) {
      case '자강조':
        return const Color(0xFF0F2557);
      case 'S조':
        return const Color(0xFF1E4FC2);
      case 'A조':
        return const Color(0xFF1A6B3C);
      case 'B조':
        return const Color(0xFF0E7490);
      case 'C조':
        return const Color(0xFF92400E);
      case 'D조':
        return const Color(0xFF4C1D95);
      case '초심조':
        return const Color(0xFF6B7A99);
      default:
        return const Color(0xFF6B7A99);
    }
  }

  // ── 연령대 색상 ───────────────────────────
  static Color decadeColor(String key) {
    switch (key) {
      case '20':
        return const Color(0xFF1E4FC2);
      case '30':
        return const Color(0xFF1A6B3C);
      case '40':
        return const Color(0xFF0E7490);
      case '50':
        return const Color(0xFF92400E);
      case '60':
        return const Color(0xFF4C1D95);
      case '70':
        return const Color(0xFF0F2557);
      default:
        return const Color(0xFF9BA8BB);
    }
  }
}

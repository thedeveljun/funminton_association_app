import 'package:flutter/material.dart';
import '../../models/venue.dart';

/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
///  배드민턴 협회 디자인 시스템
///  주조색: 딥 네이비(#0F2557) — 신뢰·권위
///  포인트: 로열 블루(#1E4FC2) + 미드나잇(#162040)
///  배경:   라이트 그레이(#F4F6FA)
///
///  코트 팔레트(13.jpg): 시민회관(민트) / 관문체육관(앰버) /
///  청소년수련관(스카이) / 과천중앙고(바이올렛). 각 5변형
///  (강조 칩 / 카드 배경 / 카드 보더 / 컬러바·도트 / 글자).
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class AppColors {
  AppColors._();

  // ── 메인 ──────────────────────────────────
  static const Color primary = Color(0xFF0F2557); // 딥 네이비
  static const Color primaryDark = Color(0xFF162040); // 미드나잇
  // 선택/강조용 블루 — 과거 #1E4FC2(로열 블루)에서 채도·명도를 한 단계
  // 낮춰 통일감 있는 톤으로 조정. 모든 선택 상태(칩/스위치/버튼)에 사용.
  static const Color primaryMid = Color(0xFF2D4F8E); // 머트 블루
  static const Color primaryLight = Color(0xFFE8EFFE); // 라이트 블루

  // 기존 호환용 alias
  static const Color blue = Color(0xFF0F2557);
  static const Color blue2 = Color(0xFF2D4F8E);
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

  // ── 12.jpg 종목 칩 ────────────────────────
  // 혼복=옅은 앰버 / 남복=옅은 분홍 / 여복=옅은 민트.
  // (bg, text) 한 쌍씩.
  static const Color eventMixedBg = Color(0xFFFFEFC2);
  static const Color eventMixedText = Color(0xFF8D6515);
  static const Color eventMaleBg = Color(0xFFFFD9DE);
  static const Color eventMaleText = Color(0xFFB03B5A);
  static const Color eventFemaleBg = Color(0xFFC9F2DC);
  static const Color eventFemaleText = Color(0xFF134228);

  static (Color bg, Color text) eventChipColors(String event) {
    switch (event) {
      case '혼복':
        return (eventMixedBg, eventMixedText);
      case '남복':
        return (eventMaleBg, eventMaleText);
      case '여복':
        return (eventFemaleBg, eventFemaleText);
      default:
        return (gray2, AppColors.text);
    }
  }

  // ── 13.jpg 코트(경기장) 팔레트 ────────────
  // 각 팔레트는 5변형: primary(컬러바·도트) / chip(강조 칩) /
  // cardBg(카드 배경) / cardBorder(카드 보더) / text(글자).
  static const VenuePalette venueMint = VenuePalette(
    name: '민트',
    primary: Color(0xFF2D7D5C),
    chip: Color(0xFFC9F2DC),
    cardBg: Color(0xFFEFFBF5),
    cardBorder: Color(0xFFD3EAD9),
    text: Color(0xFF134228),
  );
  static const VenuePalette venueAmber = VenuePalette(
    name: '앰버',
    primary: Color(0xFF8D6515),
    chip: Color(0xFFF5D976),
    cardBg: Color(0xFFFDF9EE),
    cardBorder: Color(0xFFEAD79A),
    text: Color(0xFF5E4408),
  );
  static const VenuePalette venueSky = VenuePalette(
    name: '스카이',
    primary: Color(0xFF225F8E),
    chip: Color(0xFFB8DCF7),
    cardBg: Color(0xFFEBF3FC),
    cardBorder: Color(0xFFCDDEF1),
    text: Color(0xFF0F3D5E),
  );
  static const VenuePalette venueViolet = VenuePalette(
    name: '바이올렛',
    primary: Color(0xFF4B289A),
    chip: Color(0xFFCCB5ED),
    cardBg: Color(0xFFF4EEFB),
    cardBorder: Color(0xFFDDCEEE),
    text: Color(0xFF2A1466),
  );

  static const List<VenuePalette> venuePalettes = [
    venueMint, venueAmber, venueSky, venueViolet,
  ];

  /// venue 디스플레이용 통합 헬퍼 — 앱 전체에서 동일한 색 정책을 보장한다.
  /// 1) venue.name 이 _namePalette(시민회관/관문/청소년/과천중)와 매칭되면 그 색
  /// 2) 아니면 venue 가 [allVenues] 안에서 차지하는 인덱스 % 4 순환 (mint→amber→
  ///    sky→violet). venue.colorHex 데이터가 중복이어도 인덱스 기준이라 4가지가
  ///    겹치지 않게 보장.
  ///
  /// 모든 venue 칩/카드/dot 은 이 헬퍼만 호출 — 디스플레이 일관성 단일 진실 근원.
  static VenuePalette venuePaletteForVenue(Venue v, List<Venue> allVenues) {
    final mapped = Venue.paletteHexForName(v.name);
    if (mapped != null) return venuePaletteFor(mapped);
    final idx = allVenues.indexWhere((x) => x.id == v.id);
    final safe = idx < 0 ? 0 : idx;
    return venuePalettes[safe % venuePalettes.length];
  }

  /// hex 가 4팔레트의 primary 와 정확히 매칭되면 그 팔레트를, 아니면
  /// RGB 거리(squared) 최소 팔레트를 반환. 기존 venue 색(옛 hex)도 자동으로
  /// 가장 가까운 신팔레트로 매핑되어 일관된 5변형을 제공.
  static VenuePalette venuePaletteFor(String hex) {
    final clean = hex.replaceAll('#', '').toLowerCase();
    if (clean.length != 6) return venueMint;
    int r, g, b;
    try {
      r = int.parse(clean.substring(0, 2), radix: 16);
      g = int.parse(clean.substring(2, 4), radix: 16);
      b = int.parse(clean.substring(4, 6), radix: 16);
    } catch (_) {
      return venueMint;
    }
    VenuePalette best = venueMint;
    int bestDist = 1 << 30;
    for (final p in venuePalettes) {
      final pr = (p.primary.toARGB32() >> 16) & 0xFF;
      final pg = (p.primary.toARGB32() >> 8) & 0xFF;
      final pb = p.primary.toARGB32() & 0xFF;
      final dr = pr - r;
      final dg = pg - g;
      final db = pb - b;
      final dist = dr * dr + dg * dg + db * db;
      if (dist < bestDist) {
        bestDist = dist;
        best = p;
      }
    }
    return best;
  }

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

/// 13.jpg 코트(경기장) 색상 팔레트 — 5변형 한 묶음.
class VenuePalette {
  final String name;
  final Color primary;
  final Color chip;
  final Color cardBg;
  final Color cardBorder;
  final Color text;

  const VenuePalette({
    required this.name,
    required this.primary,
    required this.chip,
    required this.cardBg,
    required this.cardBorder,
    required this.text,
  });
}

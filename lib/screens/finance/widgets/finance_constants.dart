// lib/screens/finance/widgets/finance_constants.dart
//
// 재정 화면 전반에서 쓰이는 색상/스타일 상수 모음.
// 모든 상수는 'k' 접두사를 사용해 파일 외부에서 접근 가능하도록 합니다.

import 'package:flutter/material.dart';

// ── 기본 색상 ──────────────────────────────────────
const kBgPage = Color(0xFFF6F7FA);
const kInk = Color(0xFF111111);
const kAccent = Color(0xFF5B8ABB);
const kMuted = Color(0xFF888888);

// ── 네이비 배너/박스 ──────────────────────────────
const kBannerNavy = Color.fromARGB(255, 10, 36, 92);
const kBannerNavyAlt = Color(0xFF0F2B5F);
const kBalanceNavy = Color.fromARGB(255, 12, 37, 102);
const kBannerAddBtn = Color(0xFF2A5A8A);

// ── 카드/구분선 ────────────────────────────────────
const kCardBorderLight = Color(0xFFE0E4EC);
const kPeriodActiveBg = Color(0xFFF5F7FA);

// ── 수입 (초록) ────────────────────────────────────
const kIncomeFg = Color(0xFF2A7A4A);
const kIncomeIcon = Color(0xFF4A9E6B);
const kIncomeBg = Color(0xFFE8F5EE);
const kIncomeBorder = Color(0xFF9BB5D0);

// ── 지출 (빨강) ────────────────────────────────────
const kExpenseFg = Color(0xFFCC2222);
const kExpenseIcon = Color(0xFFCC4444);
const kExpenseBg = Color(0xFFFFF0F0);
const kExpenseBorder = Color(0xFFE8A0A0);
const kExpenseCardBg = Color(0xFFFFF8F8);

// ── 요약 탭 (수입/지출/월별) ─────────────────────
const kSummaryIncomeFg = Color(0xFF217D46);
const kSummaryIncomeBg = Color(0xFFEAF5EE);
const kSummaryExpenseFg = Color(0xFFB05B5B);
const kSummaryExpenseBg = Color(0xFFFFF0F0);
const kMonthlyTitle = Color(0xFF222222);
const kMonthlyBalance = Color(0xFF1A3A5C);

// ── 협회비 상태 (납부/미납/전체) ──────────────────
const kStatusPaidColor = Color(0xFF4A9E6B);
const kStatusUnpaidColor = Color(0xFFAAAAAA);
const kStatusAllColor = Color(0xFF9DC3E6);

// ── 강조 (금액 노란색) ────────────────────────────
const kAmountYellow = Color(0xFFFFC300);

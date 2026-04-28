// lib/screens/finance/widgets/finance_helpers.dart
//
// 재정 화면에서 쓰이는 헬퍼 함수 모음.
// 모든 함수/클래스는 파일 외부에서 접근 가능하도록 'k'/'_' 접두사를 사용하지 않습니다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════
// 금액 포맷
// ══════════════════════════════════════════════

/// 정수를 "1,234,567원" 형식으로 포맷.
/// 음수일 경우 "-1,234,567원"으로 처리.
String fmtAmt(int n) {
  final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return n < 0 ? '-${s}원' : '${s}원';
}

/// 정수를 한글 표기로 변환 (예: 12345 → "일만이천삼백사십오원")
String toKoreanFull(int amount) {
  if (amount == 0) return '영원';
  final units = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  final pos = ['', '십', '백', '천'];
  final bigPos = ['', '만', '억', '조'];
  String result = '';
  int bigIdx = 0;
  int n = amount.abs();
  while (n > 0) {
    final chunk = n % 10000;
    if (chunk != 0) {
      String chunkStr = '';
      int c = chunk;
      for (int i = 0; c > 0; i++) {
        final digit = c % 10;
        if (digit != 0) {
          final d = (digit == 1 && i > 0) ? '' : units[digit];
          chunkStr = '$d${pos[i]}$chunkStr';
        }
        c ~/= 10;
      }
      result = '$chunkStr${bigPos[bigIdx]}$result';
    }
    bigIdx++;
    n ~/= 10000;
  }
  if (amount < 0) result = '마이너스$result';
  return '${result}원';
}

// ══════════════════════════════════════════════
// 거래 ID에서 시간 추출
// ══════════════════════════════════════════════

/// 거래 ID에서 시간 추출 (예: 'tx_pfp_1714276823456789' → '14:32')
/// microsecondsSinceEpoch 기반 ID에서만 동작. 추출 실패 시 빈 문자열 반환.
String extractTimeFromId(String id) {
  // ID에 들어있는 마지막 숫자 시퀀스 찾기 (>= 13자리 = 밀리초 이상)
  final match = RegExp(r'(\d{13,})').firstMatch(id);
  if (match == null) return '';
  final num = int.tryParse(match.group(1)!);
  if (num == null) return '';
  try {
    // microsecondsSinceEpoch (16자리 정도) 또는 millisecondsSinceEpoch (13자리)
    final dt = match.group(1)!.length >= 16
        ? DateTime.fromMicrosecondsSinceEpoch(num)
        : DateTime.fromMillisecondsSinceEpoch(num);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

// ══════════════════════════════════════════════
// 날짜
// ══════════════════════════════════════════════

/// 오늘 날짜를 'YYYY-MM-DD' 형식 문자열로 반환
String todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════
// 입력창 데코레이션
// ══════════════════════════════════════════════

/// 재정 화면 다이얼로그/입력창에 쓰는 통일된 InputDecoration.
InputDecoration financeInputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF5F81A7), width: 1.5),
      ),
    );

// ══════════════════════════════════════════════
// 천단위 콤마 자동 포맷터
// ══════════════════════════════════════════════

/// TextField input formatter — 입력 시 자동으로 천단위 콤마 추가.
/// 예: "1234567" → "1,234,567"
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// lib/services/finance_log.dart
//
// 재정 변경 이력 — 펀클럽(funminton_club_app) FinanceLog 를 옮겨 왔다.
//
// 수입·지출을 추가·수정·삭제하거나 협회비·분담금을 반납하면, 그 자리에서는
// 자료가 바뀌거나 사라지지만 여기에는 남는다. 이력은 앱에서 지울 수 없다.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FinanceLogEntry {
  /// 바꾼 때. `2026-07-28 13:05:11`
  final String at;

  /// 무엇을 했는지 한 줄. `지출 삭제` · `협회비 반납`
  final String what;

  /// 누구/무엇에 대한 것인지. 거래 이름이나 선수·클럽 이름.
  final String target;

  /// 바뀐 내용. `100,000원 → 50,000원`처럼 이전과 이후를 적는다.
  final String detail;

  const FinanceLogEntry({
    required this.at,
    required this.what,
    required this.target,
    this.detail = '',
  });

  Map<String, dynamic> toMap() =>
      {'at': at, 'what': what, 'target': target, 'detail': detail};

  factory FinanceLogEntry.fromMap(Map<String, dynamic> m) => FinanceLogEntry(
        at: m['at']?.toString() ?? '',
        what: m['what']?.toString() ?? '',
        target: m['target']?.toString() ?? '',
        detail: m['detail']?.toString() ?? '',
      );
}

class FinanceLog {
  FinanceLog._();

  static const String storageKey = 'data_finance_log_v1';

  /// 너무 쌓이면 저장소가 무거워지므로 최근 것만 남긴다.
  static const int maxEntries = 1000;

  static Future<List<FinanceLogEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(storageKey) ?? const [];
      return raw
          .map((s) => FinanceLogEntry.fromMap(
              Map<String, dynamic>.from(jsonDecode(s) as Map)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 이력을 덧붙인다. 새 것이 앞에 온다.
  static Future<void> add(String what, String target, [String detail = '']) =>
      addAll([
        FinanceLogEntry(at: _now(), what: what, target: target, detail: detail)
      ]);

  static Future<void> addAll(List<FinanceLogEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(storageKey) ?? const [];
      final merged = [...entries.map((e) => jsonEncode(e.toMap())), ...raw];
      await prefs.setStringList(storageKey,
          merged.length > maxEntries ? merged.sublist(0, maxEntries) : merged);
    } catch (_) {
      // 이력을 못 남겨도 본 작업은 계속되어야 한다.
    }
  }

  static String _now() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} '
        '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }
}

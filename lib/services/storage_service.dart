import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../models/scheduled_tournament.dart';
import '../models/admin_records.dart';

/// 앱 데이터(클럽/선수/대회)를 휴대폰 저장소에 영구 저장하고 불러오는 서비스
class StorageService {
  StorageService._();

  // 저장 키
  static const _kClubs = 'data_clubs_v1';
  static const _kPlayers = 'data_players_v1';
  static const _kTournaments = 'data_tournaments_v1';
  static const _kCustomGrades = 'data_custom_grades_v1';
  static const _kGradeOrder = 'data_grade_order_v1';
  static const _kScheduled = 'data_scheduled_tournaments_v1';
  static const _kNotices = 'data_notices_v1';
  static const _kBoards = 'data_boards_v1';
  static const _kDocs = 'data_docs_v1';

  // ─── CLUBS ────────────────────────────────────

  static Future<void> saveClubs(List<Club> clubs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = clubs.map((c) => c.toMap()).toList();
    await prefs.setString(_kClubs, jsonEncode(jsonList));
  }

  static Future<List<Club>?> loadClubs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClubs);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Club.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ Club 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── PLAYERS ──────────────────────────────────

  static Future<void> savePlayers(List<Player> players) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = players.map((p) => p.toMap()).toList();
    await prefs.setString(_kPlayers, jsonEncode(jsonList));
  }

  static Future<List<Player>?> loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlayers);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Player.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ Player 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── TOURNAMENTS ──────────────────────────────

  static Future<void> saveTournaments(List<Tournament> tournaments) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = tournaments.map((t) => t.toMap()).toList();
    await prefs.setString(_kTournaments, jsonEncode(jsonList));
  }

  static Future<List<Tournament>?> loadTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTournaments);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Tournament.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ Tournament 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── CUSTOM GRADES ────────────────────────────
  // 선수/동호인 관리 화면에서 운영자가 추가한 사용자 정의 급수 라벨 (예: '자강조', 'E조')

  static Future<void> saveCustomGrades(List<String> grades) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCustomGrades, grades);
  }

  static Future<List<String>> loadCustomGrades() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kCustomGrades) ?? const [];
  }

  /// 칩 표시 순서 (기본 + 사용자 추가 모두 포함된 정렬 결과).
  /// 사용자가 드래그로 재정렬한 결과를 보존.
  static Future<void> saveGradeOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kGradeOrder, order);
  }

  static Future<List<String>?> loadGradeOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kGradeOrder);
  }

  // ─── SCHEDULED TOURNAMENTS ────────────────────
  // 협회가 주관하지 않는 외부 대회 일정 (참가/참고용).

  static Future<void> saveScheduledTournaments(
      List<ScheduledTournament> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = list.map((s) => s.toMap()).toList();
    await prefs.setString(_kScheduled, jsonEncode(json));
  }

  static Future<List<ScheduledTournament>?> loadScheduledTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kScheduled);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) =>
              ScheduledTournament.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ ScheduledTournament 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── ADMIN RECORDS (공지사항/이사회/공문) ────

  static Future<void> saveNotices(List<Notice> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kNotices, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<Notice>?> loadNotices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotices);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Notice.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ Notice 데이터 로드 실패: $e');
      return null;
    }
  }

  static Future<void> saveBoards(List<BoardMeeting> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kBoards, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<BoardMeeting>?> loadBoards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBoards);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => BoardMeeting.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ BoardMeeting 데이터 로드 실패: $e');
      return null;
    }
  }

  static Future<void> saveDocs(List<OfficialDoc> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kDocs, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<OfficialDoc>?> loadDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDocs);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => OfficialDoc.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ OfficialDoc 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── 전체 초기화 ──────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClubs);
    await prefs.remove(_kPlayers);
    await prefs.remove(_kTournaments);
    await prefs.remove(_kCustomGrades);
    await prefs.remove(_kGradeOrder);
    await prefs.remove(_kScheduled);
    await prefs.remove(_kNotices);
    await prefs.remove(_kBoards);
    await prefs.remove(_kDocs);
  }
}

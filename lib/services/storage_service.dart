import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../models/scheduled_tournament.dart';
import '../models/admin_records.dart';
import '../models/player_fee_payment.dart';
import '../models/finance_transaction.dart';
import '../models/club_share.dart';
import '../models/donation.dart';

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
  static const _kPlayerFeePayments = 'data_player_fee_payments_v1';
  static const _kTransactions = 'data_transactions_v1';
  static const _kClubShares = 'data_club_shares_v1';
  static const _kDonations = 'data_donations_v1';
  static const _kPlayerFeeUnit = 'cfg_player_fee_unit_v1';
  static const _kBracketTypeFilter = 'ui_bracket_type_filter_v1';
  static const _kBracketActiveAgeGroups = 'ui_bracket_active_age_groups_v1';
  static const _kBracketActiveGrades = 'ui_bracket_active_grades_v1';
  static const _kBracketSelectedPlayers = 'ui_bracket_selected_players_v1';
  static const _kBracketSchedule = 'ui_bracket_schedule_v1';
  static const _kBracketEntryEventCounts = 'ui_bracket_entry_event_counts_v1';

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

  // ─── 대진표 참가자 탭 종별 필터 (혼복/남복/여복) ───
  // 화면 진입 시 마지막 선택을 복원하기 위한 대회별 UI 상태.
  // 키: tournamentId, 값: '혼복'|'남복'|'여복'.

  static Future<void> saveBracketTypeFilter(
      String tournamentId, String type) async {
    if (tournamentId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketTypeFilter);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        // 손상된 값은 새 맵으로 덮어쓰기
      }
    }
    map[tournamentId] = type;
    await prefs.setString(_kBracketTypeFilter, jsonEncode(map));
  }

  static Future<String?> loadBracketTypeFilter(String tournamentId) async {
    if (tournamentId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketTypeFilter);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      final v = map[tournamentId];
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  // ─── 대진표 칩 활성 상태 (연령 그룹 / 급수) ───────
  // 같은 패턴으로 대회별 List<String> 을 단일 키 JSON 맵에 저장.

  static Future<void> _saveBracketStringList(
      String key, String tournamentId, List<String> values) async {
    if (tournamentId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {/* 손상 시 새 맵 */}
    }
    map[tournamentId] = values;
    await prefs.setString(key, jsonEncode(map));
  }

  static Future<List<String>?> _loadBracketStringList(
      String key, String tournamentId) async {
    if (tournamentId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      final v = map[tournamentId];
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBracketActiveAgeGroups(
          String tournamentId, List<String> labels) =>
      _saveBracketStringList(
          _kBracketActiveAgeGroups, tournamentId, labels);

  static Future<List<String>?> loadBracketActiveAgeGroups(
          String tournamentId) =>
      _loadBracketStringList(_kBracketActiveAgeGroups, tournamentId);

  static Future<void> saveBracketActiveGrades(
          String tournamentId, List<String> labels) =>
      _saveBracketStringList(_kBracketActiveGrades, tournamentId, labels);

  static Future<List<String>?> loadBracketActiveGrades(String tournamentId) =>
      _loadBracketStringList(_kBracketActiveGrades, tournamentId);

  static Future<void> saveBracketSelectedPlayers(
          String tournamentId, List<String> playerIds) =>
      _saveBracketStringList(
          _kBracketSelectedPlayers, tournamentId, playerIds);

  static Future<List<String>?> loadBracketSelectedPlayers(
          String tournamentId) =>
      _loadBracketStringList(_kBracketSelectedPlayers, tournamentId);

  // ─── 대진표 일정 (대회 일수 + 날짜) ───────────────
  // `{tournamentId: {totalDays: N, dates: [d1,d2,d3,d4]}}` 형태로 저장.

  static Future<void> saveBracketSchedule(
      String tournamentId, int totalDays, List<String> dates) async {
    if (tournamentId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketSchedule);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {/* 손상 시 새 맵 */}
    }
    map[tournamentId] = {
      'totalDays': totalDays,
      'dates': dates,
    };
    await prefs.setString(_kBracketSchedule, jsonEncode(map));
  }

  // ─── 대진표 신청서 엑셀 누적 종목 카운트 ──────────
  // `{tournamentId: {"혼복":12,"남복":4,...}}` 형태로 저장.

  static Future<void> saveBracketEntryEventCounts(
      String tournamentId, Map<String, int> counts) async {
    if (tournamentId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketEntryEventCounts);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {/* 손상 시 새 맵 */}
    }
    map[tournamentId] = counts;
    await prefs.setString(_kBracketEntryEventCounts, jsonEncode(map));
  }

  static Future<Map<String, int>?> loadBracketEntryEventCounts(
      String tournamentId) async {
    if (tournamentId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketEntryEventCounts);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      final entry = map[tournamentId];
      if (entry is! Map) return null;
      final out = <String, int>{};
      entry.forEach((k, v) {
        final n = (v is num) ? v.toInt() : int.tryParse('$v');
        if (n != null) out[k.toString()] = n;
      });
      return out;
    } catch (_) {
      return null;
    }
  }

  /// 반환: `(totalDays, dates)` 레코드. 저장값 없으면 null.
  /// dates 길이는 0~4 가 일반적이지만 호출자가 안전하게 처리해야 함.
  static Future<({int totalDays, List<String> dates})?> loadBracketSchedule(
      String tournamentId) async {
    if (tournamentId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBracketSchedule);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      final entry = map[tournamentId];
      if (entry is! Map) return null;
      final m = Map<String, dynamic>.from(entry);
      final totalDays = (m['totalDays'] as num?)?.toInt() ?? 1;
      final datesRaw = m['dates'];
      final dates = datesRaw is List
          ? datesRaw.map((e) => e.toString()).toList()
          : <String>[];
      return (totalDays: totalDays, dates: dates);
    } catch (_) {
      return null;
    }
  }

  // ─── 협회비 단가 (협회별 정책) ──────────────────

  static Future<void> savePlayerFeeUnit(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPlayerFeeUnit, amount);
  }

  static Future<int?> loadPlayerFeeUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPlayerFeeUnit);
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

  // ─── PLAYER FEE PAYMENTS (선수별 협회비 납부) ────

  static Future<void> savePlayerFeePayments(
      List<PlayerFeePayment> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPlayerFeePayments, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<PlayerFeePayment>?> loadPlayerFeePayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlayerFeePayments);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => PlayerFeePayment.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ PlayerFeePayment 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── FINANCE TRANSACTIONS (재정 수입/지출 거래) ──

  static Future<void> saveTransactions(List<FinanceTransaction> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kTransactions, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<FinanceTransaction>?> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTransactions);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => FinanceTransaction.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ FinanceTransaction 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── CLUB SHARES (대회별 클럽 분담금) ─────────

  static Future<void> saveClubShares(List<ClubShare> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kClubShares, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<ClubShare>?> loadClubShares() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClubShares);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => ClubShare.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ ClubShare 데이터 로드 실패: $e');
      return null;
    }
  }

  // ─── DONATIONS (대회별 찬조금/물품) ───────────

  static Future<void> saveDonations(List<Donation> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kDonations, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<List<Donation>?> loadDonations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDonations);
    if (raw == null) return null;
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => Donation.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('⚠️ Donation 데이터 로드 실패: $e');
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
    await prefs.remove(_kPlayerFeePayments);
    await prefs.remove(_kTransactions);
    await prefs.remove(_kClubShares);
    await prefs.remove(_kDonations);
    await prefs.remove(_kBracketTypeFilter);
    await prefs.remove(_kBracketActiveAgeGroups);
    await prefs.remove(_kBracketActiveGrades);
    await prefs.remove(_kBracketSelectedPlayers);
    await prefs.remove(_kBracketSchedule);
    await prefs.remove(_kBracketEntryEventCounts);
  }
}

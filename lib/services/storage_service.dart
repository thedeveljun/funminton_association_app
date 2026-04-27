import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/tournament.dart';

/// 앱 데이터(클럽/선수/대회)를 휴대폰 저장소에 영구 저장하고 불러오는 서비스
class StorageService {
  StorageService._();

  // 저장 키
  static const _kClubs = 'data_clubs_v1';
  static const _kPlayers = 'data_players_v1';
  static const _kTournaments = 'data_tournaments_v1';

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

  // ─── 전체 초기화 ──────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClubs);
    await prefs.remove(_kPlayers);
    await prefs.remove(_kTournaments);
  }
}

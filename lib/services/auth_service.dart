import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 협회 등록/로그인 서비스.
/// - 첫 실행 시 협회명·회장·관리자·비밀번호 해시를 SharedPreferences 에 저장.
/// - 비밀번호는 SHA-256 해시로만 저장 (평문 저장 금지).
/// - 로그인 세션은 단순 메모리 + bool flag 로 관리. 앱 재시작하면 다시 로그인.
class AuthService {
  AuthService._();

  static const _kAssociationName = 'auth_association_name_v1';
  static const _kPresidentName = 'auth_president_name_v1';
  static const _kAdminName = 'auth_admin_name_v1';
  static const _kPasswordHash = 'auth_password_hash_v1';
  static const _kRegisteredAt = 'auth_registered_at_v1';

  // ── 캐시 (홈에서 빠르게 읽도록) ──────────────
  static String _associationName = '';
  static String _presidentName = '';
  static String _adminName = '';
  static bool _isLoggedIn = false;

  static String get associationName => _associationName;
  static String get presidentName => _presidentName;
  static String get adminName => _adminName;
  static bool get isLoggedIn => _isLoggedIn;

  /// 앱 시작 시 1회 호출 — 캐시 로드.
  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _associationName = p.getString(_kAssociationName) ?? '';
    _presidentName = p.getString(_kPresidentName) ?? '';
    _adminName = p.getString(_kAdminName) ?? '';
    _isLoggedIn = false;
  }

  /// 가입 여부 (협회명 + 비번 해시가 모두 있어야 true).
  static Future<bool> isRegistered() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString(_kAssociationName) ?? '';
    final h = p.getString(_kPasswordHash) ?? '';
    return n.isNotEmpty && h.isNotEmpty;
  }

  /// 회원가입 — 협회명/회장/관리자/비밀번호 저장.
  static Future<void> register({
    required String associationName,
    required String presidentName,
    required String adminName,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAssociationName, associationName.trim());
    await p.setString(_kPresidentName, presidentName.trim());
    await p.setString(_kAdminName, adminName.trim());
    await p.setString(_kPasswordHash, _hash(password));
    await p.setString(
        _kRegisteredAt, DateTime.now().toIso8601String());
    _associationName = associationName.trim();
    _presidentName = presidentName.trim();
    _adminName = adminName.trim();
    _isLoggedIn = true;
  }

  /// 비밀번호 검증. 성공 시 세션 플래그 ON.
  static Future<bool> verifyPassword(String password) async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kPasswordHash) ?? '';
    if (saved.isEmpty) return false;
    final ok = saved == _hash(password);
    if (ok) _isLoggedIn = true;
    return ok;
  }

  /// 세션 종료 — 다시 로그인 화면으로 이동시키려면 false.
  static void logout() {
    _isLoggedIn = false;
  }

  /// 협회 정보 수정 (비번 제외).
  static Future<void> updateProfile({
    String? associationName,
    String? presidentName,
    String? adminName,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (associationName != null) {
      _associationName = associationName.trim();
      await p.setString(_kAssociationName, _associationName);
    }
    if (presidentName != null) {
      _presidentName = presidentName.trim();
      await p.setString(_kPresidentName, _presidentName);
    }
    if (adminName != null) {
      _adminName = adminName.trim();
      await p.setString(_kAdminName, _adminName);
    }
  }

  /// 비밀번호 변경. 기존 비번이 일치해야 변경 가능.
  static Future<bool> changePassword(
      String oldPassword, String newPassword) async {
    if (!await verifyPassword(oldPassword)) return false;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPasswordHash, _hash(newPassword));
    return true;
  }

  static String _hash(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();
}

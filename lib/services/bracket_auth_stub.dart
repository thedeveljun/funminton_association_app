import 'package:flutter/foundation.dart';

/// bracket_app 의 Firebase AuthService API 를 funminton 로컬 모드에서 흉내내는 스텁.
///
/// bracket_screen.dart 등 bracket_app 에서 가져온 화면이 `AuthService.instance.*` 형태로
/// 호출하지만, funminton 은 Firebase 를 쓰지 않으므로 모든 호출이 안전한 기본값을 반환한다.
/// - currentUser: 항상 null (익명 사용자 없음)
/// - ensureSignedIn: null 반환
/// - currentRole: 'admin' 고정 ValueNotifier — UI 권한 게이트가 항상 통과
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// 로컬 모드에서는 Firebase 사용자가 없으므로 항상 null.
  _StubUser? get currentUser => null;

  /// 익명 자동 로그인 — 로컬 모드에서는 no-op, null 반환.
  Future<_StubUser?> ensureSignedIn() async => null;

  /// 사용자 역할 ValueNotifier. UI 권한 분기에 사용.
  /// 로컬 모드는 단일 사용자이므로 admin 고정.
  final ValueNotifier<String> currentRole = ValueNotifier<String>('admin');

  Stream<_StubUser?> get authStateChanges => const Stream<_StubUser?>.empty();
}

/// Firebase User 의 최소 인터페이스만 흉내내는 stub.
class _StubUser {
  String get uid => '';
  String? get email => null;
  String? get displayName => null;
  bool get isAnonymous => true;
}

/// 역할 상수 + 헬퍼. bracket_app 의 UserRole 과 동일 API.
class UserRole {
  static const String player = 'player';
  static const String scorekeeper = 'scorekeeper';
  static const String manager = 'manager';
  static const String admin = 'admin';

  static bool isManagerOrAdmin(String role) =>
      role == manager || role == admin;
}

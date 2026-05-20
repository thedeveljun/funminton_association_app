import 'package:flutter/foundation.dart';

/// bracket_app 의 Firebase Analytics API 를 funminton 에서 no-op 으로 처리하는 스텁.
/// 모든 이벤트는 debug log 로만 남기고 외부 전송하지 않는다.
class AnalyticsService {
  AnalyticsService._();

  static void _log(String name, [Map<String, Object?> params = const {}]) {
    debugPrint('[analytics-stub] $name $params');
  }

  static void tournamentCreate({required String tournamentId}) =>
      _log('tournament_create', {'tournament_id': tournamentId});

  static void inviteJoin({required String tournamentId}) =>
      _log('invite_join', {'tournament_id': tournamentId});

  static void inviteRotate({required String tournamentId}) =>
      _log('invite_rotate', {'tournament_id': tournamentId});

  static void inviteRevoke({required String tournamentId}) =>
      _log('invite_revoke', {'tournament_id': tournamentId});

  static void memberRemove({required String tournamentId}) =>
      _log('member_remove', {'tournament_id': tournamentId});

  static void bracketGenerate({
    required String tournamentId,
    required int divisionCount,
  }) =>
      _log('bracket_generate', {
        'tournament_id': tournamentId,
        'division_count': divisionCount,
      });

  static void scoreSave({
    required String tournamentId,
    required int totalMatches,
  }) =>
      _log('score_save', {
        'tournament_id': tournamentId,
        'total_matches': totalMatches,
      });

  static void signatureSave({required String tournamentId}) =>
      _log('signature_save', {'tournament_id': tournamentId});
}

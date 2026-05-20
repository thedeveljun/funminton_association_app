import 'dart:async';
import '../../models/match_score.dart';

/// bracket_app 의 Firestore MatchScoreRepo 를 funminton 로컬 모드에서 no-op 으로 흉내내는 스텁.
///
/// funminton 에서는 [BracketScreenState] 가 점수를 in-memory `_matchScores` 맵 + SharedPreferences
/// (`StorageService.saveBracketMatchScores`) 로 직접 영속화하므로, 이 repo 의 메서드는 모두
/// no-op 이어도 점수 저장/복원이 정상 동작한다. 실시간 동기화(다른 기기)는 미지원.
class MatchScoreRepo {
  MatchScoreRepo._();
  static final MatchScoreRepo instance = MatchScoreRepo._();

  /// 외부(Firestore) 변경 stream — 로컬 모드는 항상 empty.
  Stream<Map<String, MatchScore>> watchByTournament(String tournamentId) =>
      const Stream<Map<String, MatchScore>>.empty();

  Future<void> upsert(String tournamentId, MatchScore score) async {}

  Future<void> upsertMany(
          String tournamentId, Map<String, MatchScore> scores) async {}

  Future<void> delete(String tournamentId, String key) async {}

  Future<int> seedFromLocalIfEmpty(
          String tournamentId, Map<String, MatchScore> local) async =>
      0;

  Future<int> backfillMissingFields(
    String tournamentId,
    MatchScore? Function(String key) lookup, {
    required String fallbackCreatedBy,
  }) async =>
      0;

  Future<int> cleanupLegacyDocs(String tournamentId) async => 0;
}

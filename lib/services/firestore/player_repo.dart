import 'dart:async';
import '../../models/player.dart';
import '../sample_data.dart';

/// bracket_app 의 Firestore PlayerRepo 를 funminton 로컬 모드에서 흉내내는 스텁.
///
/// 실제 영속화는 [SampleData.savePlayers] / [SampleData.updatePlayer] / [SampleData.deletePlayer]
/// 가 담당. 이 repo 는 그 호출을 래핑하거나 no-op 으로 처리. 실시간 stream 은 미지원.
class PlayerRepo {
  PlayerRepo._();
  static final PlayerRepo instance = PlayerRepo._();

  Stream<List<Player>> watchAll() =>
      const Stream<List<Player>>.empty();

  Stream<List<Player>> watchByTournament(String tournamentId) =>
      const Stream<List<Player>>.empty();

  /// 대회 참가자 추가 — 선수의 tournamentIds 에 tid 추가.
  Future<void> addToTournament(String playerId, String tournamentId) async {
    final idx = SampleData.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final p = SampleData.players[idx];
    if (p.tournamentIds.contains(tournamentId)) return;
    await SampleData.updatePlayer(p.copyWith(
      tournamentIds: <String>[...p.tournamentIds, tournamentId],
    ));
  }

  Future<void> removeFromTournament(
      String playerId, String tournamentId) async {
    final idx = SampleData.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final p = SampleData.players[idx];
    if (!p.tournamentIds.contains(tournamentId)) return;
    final next = p.tournamentIds.where((t) => t != tournamentId).toList();
    await SampleData.updatePlayer(p.copyWith(tournamentIds: next));
  }

  Future<void> upsert(Player p) async => SampleData.updatePlayer(p);

  Future<void> upsertMany(Iterable<Player> list) async {
    for (final p in list) {
      await SampleData.updatePlayer(p);
    }
  }

  Future<void> delete(String id) async => SampleData.deletePlayer(id);

  Future<int> seedFromLocalIfEmpty(List<Player> local) async => 0;
}

import 'player.dart';

class MatchGame {
  final String id;
  final String tournamentId;
  final int courtNumber;
  final String venueId;
  final String venueName;
  final String venueColor;
  final String type;
  final List<Player> teamA;
  final List<Player> teamB;
  int? scoreA;
  int? scoreB;
  bool isDone;
  int day;
  String? date;

  MatchGame({
    required this.id,
    required this.tournamentId,
    required this.courtNumber,
    required this.venueId,
    required this.venueName,
    this.venueColor = '#1a3a8f',
    required this.type,
    required this.teamA,
    required this.teamB,
    this.scoreA,
    this.scoreB,
    this.isDone = false,
    this.day = 1,
    this.date,
  });

  bool get teamAWins => isDone && (scoreA ?? 0) > (scoreB ?? 0);
  bool get teamBWins => isDone && (scoreB ?? 0) > (scoreA ?? 0);
  bool get isDraw => isDone && scoreA == scoreB;
}

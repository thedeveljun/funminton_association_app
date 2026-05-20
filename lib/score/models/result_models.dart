import 'saved_match_record.dart';

class ServeSetupResult {
  final int firstServerGlobalIndex;
  final int opponentFirstServerGlobalIndex;

  const ServeSetupResult({
    required this.firstServerGlobalIndex,
    required this.opponentFirstServerGlobalIndex,
  });
}

class BulkPlayerEditResult {
  final String leftPlayer1;
  final String leftPlayer2;
  final String rightPlayer1;
  final String rightPlayer2;

  const BulkPlayerEditResult({
    required this.leftPlayer1,
    required this.leftPlayer2,
    required this.rightPlayer1,
    required this.rightPlayer2,
  });
}

class SavedMatchesPageResult {
  final List<SavedMatchRecord> savedMatches;
  final bool changed;

  const SavedMatchesPageResult({
    required this.savedMatches,
    required this.changed,
  });
}

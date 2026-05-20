/// myTeamSide: 'left' | 'right' | 'none'
/// 저장 시 사용자가 선택한 "나의 팀" 기준
class SavedMatchRecord {
  final String savedAt;
  final String leftPlayer1;
  final String leftPlayer2;
  final String rightPlayer1;
  final String rightPlayer2;
  final int scoreA;
  final int scoreB;
  final int targetScore;
  final bool useDeuce;
  final String myTeamSide; // 'left' | 'right' | 'none'
  /// 경기장·종별·급수·코트·경기번호 등 컨텍스트 라벨.
  /// 예: '혼복 40-A조 · 1코트 3경기 (한빛체육관)'. 비어 있으면 SNS 카드에서 미노출.
  final String contextLabel;

  const SavedMatchRecord({
    required this.savedAt,
    required this.leftPlayer1,
    required this.leftPlayer2,
    required this.rightPlayer1,
    required this.rightPlayer2,
    required this.scoreA,
    required this.scoreB,
    required this.targetScore,
    required this.useDeuce,
    this.myTeamSide = 'none',
    this.contextLabel = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'savedAt': savedAt,
      'leftPlayer1': leftPlayer1,
      'leftPlayer2': leftPlayer2,
      'rightPlayer1': rightPlayer1,
      'rightPlayer2': rightPlayer2,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'targetScore': targetScore,
      'useDeuce': useDeuce,
      'myTeamSide': myTeamSide,
      'contextLabel': contextLabel,
    };
  }

  factory SavedMatchRecord.fromMap(Map<String, dynamic> map) {
    return SavedMatchRecord(
      savedAt: map['savedAt'] as String? ?? '',
      leftPlayer1: map['leftPlayer1'] as String? ?? '선수1',
      leftPlayer2: map['leftPlayer2'] as String? ?? '선수2',
      rightPlayer1: map['rightPlayer1'] as String? ?? '선수3',
      rightPlayer2: map['rightPlayer2'] as String? ?? '선수4',
      scoreA: map['scoreA'] as int? ?? 0,
      scoreB: map['scoreB'] as int? ?? 0,
      targetScore: map['targetScore'] as int? ?? 25,
      useDeuce: map['useDeuce'] as bool? ?? false,
      myTeamSide: map['myTeamSide'] as String? ?? 'none',
      contextLabel: map['contextLabel'] as String? ?? '',
    );
  }
}

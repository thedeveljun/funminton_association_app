// 매치 점수 키 빌드 — BracketScreen(점수판/수동 입력 저장) 과 BracketGeneratorTab
// (_DivisionCard 매치 셀/순위표 표시) 가 공유한다.
//
// key 포맷: "event|age|grade|group|matchNum" — 매치 위치만으로 안정한 ID.
// 팀 구성(누가 경기했는지) 은 MatchScore.teamA/teamB 필드에 저장. 페어 변경 시
// 옛 점수는 클라이언트단 set 비교로 무효화 — doc ID 에 팀 해시를 섞지 않는다
// (Firestore 에 leak 발생 방지).

String matchScoreKey({
  required String event,
  required String age,
  required String grade,
  required String groupName,
  required int matchNum,
}) =>
    '$event|$age|$grade|$groupName|$matchNum';

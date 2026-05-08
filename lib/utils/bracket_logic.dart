// 배드민턴 대진표 자동 생성 — 알고리즘 (순수 함수)
// (reference/bracket_reference.dart SECTION 2)

import '../models/bracket_models.dart';

/// 팀 수에 따라 대진방식 자동 결정.
/// 4팀 미만이면 null 반환 (협회 규정상 진행 불가).
BracketFormat? determineFormat(int n) {
  if (n < 4) return null;

  // 헬퍼: 총 팀을 k개 조로 균등 분할
  List<int> split(int total, int k) {
    final base = total ~/ k;
    final rem = total % k;
    return List.generate(k, (i) => base + (i < rem ? 1 : 0));
  }

  // 4-5팀: 풀리그 단독
  if (n <= 5) {
    return BracketFormat(
      groups: [GroupInfo(size: n, name: '본선', matches: n * (n - 1) ~/ 2)],
      finals: null,
      format: '풀리그 단독',
    );
  }

  late List<int> sizes;
  late int fSize;
  bool recommended = false;

  if (n == 6) {
    sizes = [3, 3];
    fSize = 2;
  } else if (n == 7) {
    sizes = [4, 3];
    fSize = 2;
  } else if (n == 8) {
    sizes = [4, 4];
    fSize = 4;
  } else if (n == 9) {
    sizes = [3, 3, 3];
    fSize = 3;
  } else if (n == 10) {
    sizes = [5, 5];
    fSize = 4;
  } else if (n == 11) {
    sizes = [6, 5];
    fSize = 4;
    recommended = true;
  } else if (n == 12) {
    sizes = [3, 3, 3, 3];
    fSize = 4;
  } else if (n <= 16) {
    sizes = split(n, 4);
    fSize = 8;
  } else if (n <= 24) {
    sizes = split(n, (n / 4).ceil());
    fSize = 8;
  } else if (n <= 32) {
    sizes = split(n, 8);
    fSize = 8;
  } else if (n <= 48) {
    sizes = split(n, (n / 4).ceil());
    fSize = 16;
  } else if (n <= 64) {
    sizes = split(n, 16);
    fSize = 16;
  } else {
    sizes = split(n, (n / 5).ceil());
    fSize = 32;
  }

  final groups = <GroupInfo>[];
  for (int i = 0; i < sizes.length; i++) {
    groups.add(GroupInfo(
      size: sizes[i],
      name: '${String.fromCharCode(65 + i)}조',
      matches: sizes[i] * (sizes[i] - 1) ~/ 2,
    ));
  }

  const fNames = {
    2: '결승',
    3: '본선(3강)',
    4: '4강',
    8: '8강',
    16: '16강',
    32: '32강',
  };

  return BracketFormat(
    groups: groups,
    finals: FinalsInfo(
      size: fSize,
      name: fNames[fSize]!,
      matches: fSize - 1,
    ),
    format: '${groups.length}개 조 풀리그 + ${fNames[fSize]} 토너먼트',
    recommended: recommended,
  );
}

/// 조의 모든 경기에 코트 번호와 시간 자동 배정.
/// 1경기 30분 (25점 + 코트 전환 5분) 기준.
List<MatchInfo> generateMatches({
  required GroupInfo group,
  required int courts,
  int startCourt = 1,
  int startMatchNum = 1,
  String startTime = '13:00',
}) {
  final matches = <MatchInfo>[];
  final n = group.size;
  int mNum = startMatchNum;
  int courtIdx = 0;
  final timeParts = startTime.split(':');
  final timeMin =
      int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);

  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      final court = (courtIdx % courts) + startCourt;
      final round = courtIdx ~/ courts;
      final t = timeMin + round * 30;
      final hh = (t ~/ 60).toString().padLeft(2, '0');
      final mm = (t % 60).toString().padLeft(2, '0');

      matches.add(MatchInfo(
        num_: mNum,
        court: court,
        team1Index: i,
        team2Index: j,
        time: '$hh:$mm',
      ));
      mNum++;
      courtIdx++;
    }
  }
  return matches;
}

/// 팀 수에 따른 다각형 한글 이름.
String polygonName(int n) {
  const names = [
    '', '', '', '삼각형', '사각형', '오각형', '육각형', '칠각형', '팔각형'
  ];
  return n < names.length ? names[n] : '$n각형';
}

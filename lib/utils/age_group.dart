/// 연령 그룹 라벨 ↔ 나이 매칭 헬퍼
///
/// 규칙: 모든 라벨은 5세 단위 버킷
/// - "전체"  → 모든 나이
/// - "X대"  → [X, X+5)
///   예) 40대 = 40~44, 45대 = 45~49, 50대 = 50~54, 55대 = 55~59, 70대 = 70~74
///
/// TODO: tournament_form_screen에서 ageGroups 편집 UI를 만들 때 같은 규칙 사용
library;

bool ageGroupMatches(String label, int age) {
  if (label == '전체') return true;

  final start = int.tryParse(label.replaceAll('대', ''));
  if (start == null) return false;

  return age >= start && age < start + 5;
}

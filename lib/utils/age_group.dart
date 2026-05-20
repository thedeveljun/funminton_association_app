/// 연령 그룹 라벨 ↔ 나이 매칭 헬퍼
///
/// 라벨 종류:
/// - "전체"   → 모든 나이
/// - 숫자     → 자동 매칭. 다음 5단위 라벨 존재 시 [N, N+5), 없으면 [N, N+10).
///   마지막 라벨이 70 이상이면 [N, ∞).
/// - 그 외 텍스트 ("고등학생" 등) → 자동 매칭 안 함 (운영자 수동 선택용).
/// 옛 형식("X대")이 들어오면 자동으로 '대' 제거 후 동일 규칙 적용.
library;

bool ageMatches(String label, int age, List<String> allLabels) {
  if (label == '전체') return true;

  // 병합 라벨 ("20·30" 처럼 가운뎃점으로 묶임) — 각 구성요소를 OR 로 평가.
  if (label.contains('·')) {
    for (final part in label.split('·')) {
      if (ageMatches(part, age, allLabels)) return true;
    }
    return false;
  }

  final norm = label.replaceAll('대', '');
  final start = int.tryParse(norm);
  if (start == null) return false;

  if (start >= 70) return age >= start;

  final hasNext5 = allLabels
      .map((l) => l.replaceAll('대', ''))
      .contains((start + 5).toString());
  final end = hasNext5 ? start + 5 : start + 10;
  return age >= start && age < end;
}

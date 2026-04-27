/// 앱 운영 설정 (협회별 정책)
class AppConfig {
  AppConfig._();

  // ── 협회비 정책 ─────────────────────────────
  /// 정기 협회비 기본 금액 (클럽당 연 1회)
  static int regularFeeDefault = 300000;

  /// 신규 회원 1인당 추가 협회비 단가
  static int newMemberFeePerHead = 15000;

  // ── 분담금 정책 ─────────────────────────────
  /// 협회장기대회 분담금 회원수당 단가 (예시)
  static int shareFeePerMember = 0;
}

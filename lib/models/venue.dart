/// 대회 경기장 모델
///
/// 한 대회에서 운영하는 개별 경기장 1곳을 표현.
/// 영속화는 Tournament.venues 가 담당하며 toMap/fromMap 으로 직렬화.
class Venue {
  String id;
  String name;
  String address;
  int courts;
  String colorHex;

  Venue({
    this.id = '',
    this.name = '',
    this.address = '',
    this.courts = 4,
    this.colorHex = '#2D7D5C',
  });

  // 13.jpg 코트 팔레트 4가지의 primary hex — AppColors.venuePaletteFor 가
  // 이 값을 키로 5변형(강조 칩 / 카드 배경 / 카드 보더 / 컬러바·도트 / 글자)을 제공.
  // 5개 이상의 venue 추가 시에는 순환(반복 사용).
  static const List<String> defaultColors = [
    '#2D7D5C', // 민트   (시민회관)
    '#8D6515', // 앰버   (관문체육관)
    '#225F8E', // 스카이 (청소년수련관)
    '#4B289A', // 바이올렛 (과천중앙고)
  ];

  /// 이름 → 신팔레트 primary hex. fromMap 에서 옛 hex 자동 마이그레이션 용도.
  /// (사용자가 picker 로 신팔레트 색을 선택한 경우는 colorHex 가 이미 defaultColors
  /// 중 하나라 변환 대상이 아님 → 사용자 선택 보존.)
  static const Map<String, String> _namePalette = {
    '시민회관': '#2D7D5C',
    '관문체육관': '#8D6515',
    '청소년수련관': '#225F8E',
    '과천중앙고': '#4B289A',
  };

  /// 이름이 알려진 venue 면 그 신팔레트 primary hex 반환. UI 가 venue.colorHex
  /// 대신 이름 기준으로 palette 를 고를 수 있도록 외부 노출.
  static String? paletteHexForName(String name) => _namePalette[name];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'courts': courts,
        'color_hex': colorHex,
      };

  factory Venue.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString();
    var color = (m['color_hex'] ?? defaultColors[0]).toString();
    // 이름 매핑(_namePalette)에 있으면 무조건 그 색으로 — 두 venue 가 우연히 같은
    // 신팔레트 hex 로 저장된 경우(예: 관문/청소년 둘 다 amber)에도 강제로 구분.
    // 사용자가 picker 로 다른 색을 골랐다면, 이름을 _namePalette 키와 다르게 변경
    // 하면 됨.
    final mapped = _namePalette[name];
    if (mapped != null) {
      color = mapped;
    }
    return Venue(
      id: (m['id'] ?? '').toString(),
      name: name,
      address: (m['address'] ?? '').toString(),
      courts: m['courts'] is int
          ? m['courts'] as int
          : int.tryParse((m['courts'] ?? '').toString()) ?? 4,
      colorHex: color,
    );
  }

  Venue copyWith({
    String? id,
    String? name,
    String? address,
    int? courts,
    String? colorHex,
  }) =>
      Venue(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        courts: courts ?? this.courts,
        colorHex: colorHex ?? this.colorHex,
      );
}

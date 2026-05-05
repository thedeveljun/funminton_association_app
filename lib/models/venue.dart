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
    this.colorHex = '#1a3a8f',
  });

  static const List<String> defaultColors = [
    '#1a3a8f',
    '#2a7d4f',
    '#9c4221',
    '#553ab7',
    '#b7791f',
    '#1a7a9f',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'courts': courts,
        'color_hex': colorHex,
      };

  factory Venue.fromMap(Map<String, dynamic> m) => Venue(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        address: (m['address'] ?? '').toString(),
        courts: m['courts'] is int
            ? m['courts'] as int
            : int.tryParse((m['courts'] ?? '').toString()) ?? 4,
        colorHex: (m['color_hex'] ?? defaultColors[0]).toString(),
      );

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

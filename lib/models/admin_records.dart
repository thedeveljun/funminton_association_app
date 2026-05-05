/// 협회 행정 — 공지사항/이사회/공문 모델 모음.
/// 각 모델은 SharedPreferences 에 JSON 형태로 영속화.

class Notice {
  final String id;
  final String title;
  final String type; // '중요' | '일반'
  final String date; // YYYY-MM-DD
  final String content;

  const Notice({
    required this.id,
    required this.title,
    this.type = '일반',
    required this.date,
    this.content = '',
  });

  Notice copyWith({
    String? title,
    String? type,
    String? date,
    String? content,
  }) =>
      Notice(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        date: date ?? this.date,
        content: content ?? this.content,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'date': date,
        'content': content,
      };

  factory Notice.fromMap(Map<String, dynamic> m) => Notice(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        type: (m['type'] ?? '일반').toString(),
        date: (m['date'] ?? '').toString(),
        content: (m['content'] ?? '').toString(),
      );
}

class BoardMeeting {
  final String id;
  final String title;
  final String date;
  final String place;
  final String status; // '예정' | '완료'
  final String agenda;

  const BoardMeeting({
    required this.id,
    required this.title,
    required this.date,
    this.place = '',
    this.status = '예정',
    this.agenda = '',
  });

  BoardMeeting copyWith({
    String? title,
    String? date,
    String? place,
    String? status,
    String? agenda,
  }) =>
      BoardMeeting(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        place: place ?? this.place,
        status: status ?? this.status,
        agenda: agenda ?? this.agenda,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'place': place,
        'status': status,
        'agenda': agenda,
      };

  factory BoardMeeting.fromMap(Map<String, dynamic> m) => BoardMeeting(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        place: (m['place'] ?? '').toString(),
        status: (m['status'] ?? '예정').toString(),
        agenda: (m['agenda'] ?? '').toString(),
      );
}

class OfficialDoc {
  final String id;
  final String title;
  final String date;
  final String to; // 수신처
  final String content;

  const OfficialDoc({
    required this.id,
    required this.title,
    required this.date,
    this.to = '',
    this.content = '',
  });

  OfficialDoc copyWith({
    String? title,
    String? date,
    String? to,
    String? content,
  }) =>
      OfficialDoc(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        to: to ?? this.to,
        content: content ?? this.content,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'to': to,
        'content': content,
      };

  factory OfficialDoc.fromMap(Map<String, dynamic> m) => OfficialDoc(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        to: (m['to'] ?? '').toString(),
        content: (m['content'] ?? '').toString(),
      );
}

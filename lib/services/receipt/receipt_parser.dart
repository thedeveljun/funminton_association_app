/// 영수증 사진에서 읽은 글자로 **업체명·날짜·최종금액**을 골라낸다.
///
/// 글자 읽기(OCR)는 화면 쪽([ReceiptScanner])이 하고, 여기는 읽은 줄만 받아
/// 고른다 — 폰 없이 시험할 수 있게 떼어 두었다.
///
/// 영수증은 가게마다 꼴이 달라 **틀릴 수 있다.** 그래서 채워 주기만 하고
/// 저장은 사람이 보고 한다. 못 찾은 칸은 널로 두어 손으로 적게 한다.
library;

import 'dart:math' as math;

/// 읽은 글자 한 줄과 사진 속 자리(왼·위·오른·아래, 픽셀).
///
/// 영수증은 `합계        45,000` 처럼 이름과 금액이 멀리 떨어져 있어, 글자
/// 읽기가 둘을 **다른 줄로** 돌려줄 때가 많다. 높이가 같은 줄을 짝지으려고
/// 자리를 함께 받는다.
class ReceiptLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const ReceiptLine(this.text, this.left, this.top, this.right, this.bottom);

  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// 글자 읽기가 돌려준 한 줄 그대로 — 글자와 네 귀퉁이(왼위·오른위·오른아래·왼아래).
class ReceiptQuad {
  final String text;
  final List<math.Point<double>> corners;

  const ReceiptQuad(this.text, this.corners);
}

/// 기울어진 사진을 바로 편다.
///
/// 영수증을 비스듬히 찍으면 오른쪽 금액 열이 왼쪽 이름표보다 반 줄쯤 처진다.
/// 그러면 '합계' 높이에 바로 위 '부가세' 금액이 걸린다(실제로 42,000원 대신
/// 3,818원이 들어갔다). 글자 줄마다 기운 각도를 재어 **가운데 값**만큼 모든
/// 귀퉁이를 되돌린 뒤 [ReceiptLine] 으로 만든다.
List<ReceiptLine> straightenReceipt(List<ReceiptQuad> quads) {
  final angles = <double>[];
  for (final q in quads) {
    if (q.corners.length < 4) continue;
    final a = q.corners[0], b = q.corners[1], d = q.corners[3];
    final len = a.distanceTo(b);
    // 글자 두세 자 이상인 줄만 잰다 — 짧은 줄은 각도가 들쭉날쭉하다.
    if (len < a.distanceTo(d) * 2) continue;
    angles.add(math.atan2(b.y - a.y, b.x - a.x));
  }
  angles.sort();
  final angle = angles.isEmpty ? 0.0 : angles[angles.length ~/ 2];
  final c = math.cos(-angle), s = math.sin(-angle);
  return [
    for (final q in quads)
      if (q.corners.isNotEmpty)
        () {
          final xs = <double>[], ys = <double>[];
          for (final p in q.corners) {
            xs.add(p.x * c - p.y * s);
            ys.add(p.x * s + p.y * c);
          }
          return ReceiptLine(
            q.text,
            xs.reduce(math.min),
            ys.reduce(math.min),
            xs.reduce(math.max),
            ys.reduce(math.max),
          );
        }(),
  ];
}

class ReceiptInfo {
  /// 업체명(식당명). 못 찾으면 널.
  final String? store;

  /// `2026-10-08` 또는 시각까지 `2026-10-08 19:32:00`. 못 찾으면 널.
  final String? date;

  /// 최종금액(원). 못 찾으면 널.
  final int? amount;

  /// 가맹점 전화번호(`02-1234-5678` 꼴). 못 찾으면 널.
  final String? phone;

  const ReceiptInfo({this.store, this.date, this.amount, this.phone});

  bool get isEmpty =>
      store == null && date == null && amount == null && phone == null;

  @override
  String toString() =>
      'store=$store date=$date amount=$amount phone=$phone';
}

class ReceiptParser {
  /// 최종금액을 가리키는 말. **앞에 있을수록 믿는다** — '받을금액'·'결제금액'은
  /// 할인까지 뺀 마지막 금액이고, '합계'는 할인 전일 수 있다.
  static const List<String> totalKeys = [
    '받을금액',
    '받을액',
    '결제금액',
    '결제액',
    '승인금액',
    '청구금액',
    '판매금액',
    '합계금액',
    '총합계',
    '총금액',
    '총액',
    '합계',
    '계',
  ];

  /// 금액 줄이지만 최종금액이 아닌 것 — 세금·할인·거스름 등.
  static const List<String> _notTotal = [
    '부가세',
    '부가가치세',
    '세액',
    '과세',
    '면세',
    '공급가',
    '봉사료',
    '할인',
    '거스름',
    '받은금액',
    '받은돈',
    '현금',
    '포인트',
    '잔액',
    '잔여',
    '적립',
    '수량',
    '단가',
  ];

  /// 업체명을 가리키는 말. **앞에 있을수록 먼저 본다.**
  ///
  /// '상호·상호명·업체명·업체' 오른쪽 글자가 곧 업체명이다(사용자 규칙) —
  /// 그래서 맨 앞에 둔다. 카드 단말기 영수증은 '상호:한빛상회 대표자:…'처럼
  /// 한 줄에 여러 이름표를 늘어놓는다.
  ///
  /// 글자 읽기가 '가맹점'을 '기맹점'·'가맹짐'처럼 한 글자씩 틀리게 읽기도 해서
  /// 그 꼴도 받는다(실제 영수증에서 '가맹짐'으로 읽혔다).
  static const List<String> _storeKeys = [
    '상호명',
    '업체명',
    '상호',
    // 글자 읽기가 '호'를 '흐'·'효'로, '상'을 '삼'으로 읽기도 한다(실제 전표에서 '상흐').
    '상흐',
    '상효',
    '삼호',
    '업체',
    '가맹점명',
    '기맹점명',
    '가맹짐명',
    '가맹점멍',
    '상호명',
    '매장명',
    '점포명',
    '가게명',
    '가맹점',
  ];

  /// 이름표 값이 끝나는 자리 — 같은 줄의 다음 이름표(`대표자:`·`전표No` 등)나
  /// 두 칸 넘는 빈칸. 그 앞까지만 이름이다.
  static final RegExp _nextLabel = RegExp(
    // 빈칸 뒤에 오거나 ':' 이 붙은 이름표만 — '대표횟집' 같은 가게 이름 속
    // 낱말에서 자르지 않게.
    r'\s{2,}|\s+(?:대표자|대표|사업자|등록번호|전표|단말기|전화|TEL|Tel|tel|주소|No|NO)|(?:대표자|사업자|전표|단말기|전화|TEL|Tel|주소|No|NO)\s*[:：.]',
  );

  /// 업체명이 없을 때 대신 쓰는 대표자 이름표.
  static const List<String> _ownerKeys = ['대표자명', '대표자', '대표'];

  /// 업체명·대표자 이름이 아닌 줄(다른 이름표·안내문).
  static const List<String> _notStore = [
    '영수증',
    '승인',
    '매출전표',
    '전표',
    '고객용',
    '카드',
    '신용',
    '사업자',
    '대표',
    '주소',
    '전화',
    'TEL',
    'Tel',
    '주문',
    '테이블',
    '거래',
    '판매',
    '일시',
    'POS',
    '번호',
    '번로',
    '환영',
    '감사',
    '재발행',
    '잔여',
  ];

  static ReceiptInfo parse(List<ReceiptLine> raw, {DateTime? today}) {
    final lines = [...raw.where((l) => l.text.trim().isNotEmpty)]
      ..sort((a, b) => a.top.compareTo(b.top));
    return ReceiptInfo(
      store: _store(lines),
      date: _date(lines, today ?? DateTime.now()),
      amount: _amount(lines),
      phone: _phone(lines),
    );
  }

  // ── 금액 ──────────────────────────────────────────────────────────

  /// 천 단위 쉼표(글자 읽기가 점으로 읽기도 한다)가 있거나 뒤에 '원'이 붙은 수.
  /// 쉼표 없는 맨 숫자는 전화·사업자번호와 섞이므로 '원'이 붙을 때만 받는다.
  static final RegExp _money = RegExp(
    r'(?<![\d,.\-])(\d{1,3}(?:[,.]\d{3})+|\d{3,8}(?=\s*원))(?![\d\-])',
  );

  /// 글자 읽기가 숫자를 흔히 틀리는 꼴을 바로잡는다.
  /// - 숫자 곁의 O·o·D 는 0, I·l 은 1 (`32,5O0` → `32,500`)
  /// - 쉼표·점 뒤에 끼어든 빈칸 (`32, 500` → `32,500`)
  static String _fixDigits(String s) {
    var t = s;
    for (var i = 0; i < 2; i++) {
      t = t
          .replaceAllMapped(
            RegExp(r'(?<=[\d,.])[OoDC]|[OoDC](?=[\d,.])'),
            (_) => '0',
          )
          .replaceAllMapped(RegExp(r'(?<=[\d,.])[Il]|[Il](?=[\d,.])'), (_) => '1');
    }
    t = t.replaceAllMapped(
      RegExp(r'(\d[,.])\s+(\d{3})(?=\d?(?!\d))'),
      (m) => '${m[1]}${m[2]}',
    );
    // 줄 끝 금액의 쉼표를 빈칸으로 읽은 것(`52 000`). 줄 끝에서만 —
    // 줄 가운데의 '480 20 00602' 같은 번호를 금액으로 잡지 않게.
    t = t.replaceAllMapped(
      RegExp(r'(?<![\d,.\s])(\d{1,3}) (\d{3})(\s*원?\s*)$'),
      (m) => '${m[1]},${m[2]}${m[3]}',
    );
    // 쉼표 뒤는 늘 세 자리다. 네 자리면 끝의 하나는 '원'을 숫자로 읽은 것
    // (`50,000원` → `50, 0002`, `45,455원` → `45, 4555`).
    return t.replaceAllMapped(
      RegExp(r'(\d[,.]\d{3})\d(?!\d)'),
      (m) => '${m[1]}원',
    );
  }

  static int? _moneyIn(String s) {
    int? best;
    for (final m in _money.allMatches(_fixDigits(s))) {
      final v = int.tryParse(m.group(1)!.replaceAll(RegExp(r'[,.]'), ''));
      // 1,000원 미만은 최종금액으로 보지 않는다 — 부서져 읽힌 금액의 끝자리
      // (42,000 → '818원')를 집는 일이 있었다. 틀리게 채우느니 비운다.
      if (v == null || v < 1000 || v > 100000000) continue;
      // 한 줄에 금액이 여럿이면(단가·금액) 오른쪽 끝 것이 그 줄의 금액이다.
      best = v;
    }
    return best;
  }

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

  static bool _sameRow(ReceiptLine a, ReceiptLine b) {
    final h = a.height > b.height ? a.height : b.height;
    return (a.centerY - b.centerY).abs() <= h * 0.6;
  }

  /// 이름 줄에 붙은 금액.
  /// 1) 같은 줄 안 2) 같은 높이 오른쪽 줄(높이가 가장 가까운 것)
  /// 3) 바로 아랫줄 오른쪽 — 금액이 이름보다 반 줄쯤 아래 찍힌 영수증이 있다.
  static int? _valueBeside(ReceiptLine label, List<ReceiptLine> lines) {
    final own = _moneyIn(label.text);
    if (own != null) return own;
    ReceiptLine? best;
    double bestGap = double.infinity;
    for (final l in lines) {
      if (identical(l, label) || l.left < label.right - 4) continue;
      if (_moneyIn(l.text) == null) continue;
      final dy = l.centerY - label.centerY;
      final h = label.height > l.height ? label.height : l.height;
      // 같은 높이, 또는 한 줄 반 안쪽 아래.
      if (dy < -h * 0.6 || dy > h * 1.6) continue;
      final gap = dy.abs();
      if (gap < bestGap) {
        best = l;
        bestGap = gap;
      }
    }
    return best == null ? null : _moneyIn(best.text);
  }

  static int? _amount(List<ReceiptLine> lines) {
    final byVat = _amountByVat(lines);
    if (byVat != null) return byVat;
    for (final key in totalKeys) {
      int? found;
      for (final l in lines) {
        final t = _squash(l.text);
        if (!t.contains(key)) continue;
        if (_notTotal.any((n) => t.contains(n))) continue;
        // '계' 한 글자는 다른 낱말(계좌·계산 등) 속에도 있다 — 줄이 거의
        // '계'뿐일 때만 받는다('합'과 '계:'가 따로 읽힌 때).
        if (key.length == 1 && t.replaceAll(RegExp(r'[\d,.:원\s]'), '') != key) {
          continue;
        }
        final v = _valueBeside(l, lines);
        // 같은 이름이 여러 번 나오면(합계·카드 합계) 아래 것이 마지막 금액이다.
        if (v != null) found = v;
      }
      if (found != null) return found;
    }
    // 합계 이름표는 있는데 금액을 못 읽었으면 **비워 둔다.** 아무 금액이나
    // 집으면 세금(3,272원 등)이 들어가 틀린 줄도 모르고 저장한다.
    final hasTotalLabel = lines.any((l) {
      final t = _squash(l.text).replaceAll(RegExp(r'[:：.,]'), '');
      return totalKeys.any((k) => k.length > 1 && t.contains(k)) ||
          const ['총', '액', '합', '계'].contains(t);
    });
    if (hasTotalLabel) {
      // 큰 글씨 '거래금액'·'총금액'이 '거래'·'총'처럼 조각나 읽히면 이름표로는
      // 못 찾는다. 조각 옆(같은 높이)의 금액은 믿을 만하다 — 아래 것이 마지막 금액.
      int? frag;
      for (final l in lines) {
        final t = _squash(l.text).replaceAll(RegExp(r'[:：.,]'), '');
        if (!const ['총', '합', '계', '거래', '결제', '총금', '받을'].contains(t)) continue;
        final v = _valueBeside(l, lines);
        if (v != null) frag = v;
      }
      return frag;
    }
    // 이름표가 아예 없으면 가장 큰 금액. 세금·할인 줄은 뺀다.
    int? best;
    for (final l in lines) {
      final t = _squash(l.text);
      if (_notTotal.any((n) => t.contains(n))) continue;
      final v = _moneyIn(l.text);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  /// **공급가 + 부가세 = 총액** 이 맞아떨어지는 세 금액을 찾아 총액을 고른다.
  ///
  /// 큰 글씨 '총금액'은 글자 읽기가 '액:'·'대들'처럼 부숴 읽어 이름표로는
  /// 못 찾는 일이 잦다. 숫자는 대개 멀쩡하게 읽힌다. 한국 영수증은 부가세가
  /// 총액의 1/11 이라, 이 셋이 맞으면 이름표 없이도 총액이 확실하다.
  /// (예: 45,455 + 4,545 = 50,000)
  static int? _amountByVat(List<ReceiptLine> lines) {
    final values = <int>{};
    for (final l in lines) {
      for (final m in _money.allMatches(_fixDigits(l.text))) {
        final v = int.tryParse(m.group(1)!.replaceAll(RegExp(r'[,.]'), ''));
        if (v != null && v >= 1000 && v <= 100000000) values.add(v);
      }
    }
    final sorted = values.toList()..sort((a, b) => b.compareTo(a));
    for (final total in sorted) {
      for (final tax in values) {
        if (tax >= total || (tax - total / 11).abs() > 2) continue;
        if (values.contains(total - tax)) return total;
      }
    }

    // 합계 숫자가 아예 안 읽혔어도 **공급가와 그 10%인 부가세**가 보이면
    // 더해서 낸다(63,636 + 6,364 = 70,000). 부가세는 쉼표 없이 읽히기도
    // 해서('6364') 한 줄에 숫자만 있는 것도 받는다.
    final taxes = <int>{...values};
    for (final l in lines) {
      final t = _fixDigits(l.text).replaceAll(RegExp(r'[\s원]'), '');
      if (RegExp(r'^\d{3,7}$').hasMatch(t)) taxes.add(int.parse(t));
    }
    for (final supply in sorted) {
      for (final tax in taxes) {
        if ((tax - supply / 10).abs() <= 1) return supply + tax;
      }
    }
    return null;
  }

  // ── 전화번호 ──────────────────────────────────────────────────────

  /// 전화번호. 02-123-4567 · 031-123-4567 · 010-1234-5678 · 1588-1234.
  static final RegExp _phoneRe = RegExp(
    r'(?<!\d)(0\d{1,2})[\s)\-.]*(\d{3,4})[\s\-.]*(\d{4})(?!\d)|(?<!\d)(1[5-9]\d{2})[\s\-.]*(\d{4})(?!\d)',
  );

  /// 가맹점 전화번호를 가리키는 말. 앞에 있을수록 믿는다.
  static const List<String> _phoneKeys = [
    '가맹점전화',
    '전화번호',
    '전화',
    'TEL',
    'Tel',
    'tel',
    'T.',
  ];

  /// 가맹점 번호가 아닌 전화 — 카드 영수증 머리의 여신금융협회 신고 번호 등.
  static const List<String> _notStorePhone = ['협회', '신고', '고객센터', '상담'];

  /// 있는 지역·통신 번호만 — 02, 031~064, 010·011·016~019, 070.
  /// 잘못 읽어 '06-123-4567'처럼 없는 번호가 되면 비워서 손으로 적게 한다.
  static final RegExp _areaCode = RegExp(r'^(02|0[3-6][1-5]|01[016-9]|070)$');

  static String? _phoneIn(String s) {
    for (final m in _phoneRe.allMatches(_fixDigits(s))) {
      if (m.group(1) == null) return '${m[4]}-${m[5]}';
      if (_areaCode.hasMatch(m[1]!)) return '${m[1]}-${m[2]}-${m[3]}';
    }
    return null;
  }

  static String? _phone(List<ReceiptLine> lines) {
    bool ok(ReceiptLine l) =>
        !_notStorePhone.any(_squash(l.text).contains);
    for (final key in _phoneKeys) {
      for (final l in lines) {
        if (!ok(l)) continue;
        final raw = _afterKey(l.text, key);
        if (raw == null) continue;
        final own = _phoneIn(raw);
        if (own != null) return own;
        // 이름표와 번호가 따로 읽혔으면 같은 높이 오른쪽 줄.
        for (final o in lines) {
          if (identical(o, l) || !_sameRow(o, l) || o.left < l.right - 4) {
            continue;
          }
          final v = _phoneIn(o.text);
          if (v != null) return v;
        }
      }
    }
    // 이름표가 없으면 협회 안내가 아닌 줄의 첫 전화번호.
    for (final l in lines) {
      if (!ok(l)) continue;
      // 사업자번호(123-45-67890)·카드번호 줄은 건너뛴다.
      if (RegExp(r'사업자|카드|승인|가맹점번호|단말기').hasMatch(_squash(l.text))) {
        continue;
      }
      final v = _phoneIn(l.text);
      if (v != null) return v;
    }
    return null;
  }

  // ── 날짜 ──────────────────────────────────────────────────────────

  static final List<RegExp> _dates = [
    // 2026-10-08 · 2026.10.08 · 2026/10/08 · 2026년 10월 8일
    RegExp(r'(?<!\d)(20\d{2})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})(?!\d)'),
    // 2016 11 22 — 구분 기호를 빈칸으로 읽은 것
    RegExp(r'(?<![\d,.])(20\d{2}) (\d{1,2}) (\d{1,2})(?![\d,.])'),
    // 20261008
    RegExp(r'(?<!\d)(20\d{2})(\d{2})(\d{2})(?!\d)'),
    // 26-10-08 · 26.10.08 · 26/10/08
    RegExp(r'(?<![\d\-])(\d{2})[-./](\d{1,2})[-./](\d{1,2})(?![\d\-])'),
  ];

  static final RegExp _time = RegExp(
    // 글자 읽기가 콜론 곁에 빈칸을 끼우기도 한다(`15: 25:14`).
    r'(?<!\d)([01]?\d|2[0-3])\s*[:.]\s*([0-5]\d)(?:\s*[:.]\s*([0-5]\d))?(?!\d)',
  );

  static final RegExp _colonTime = RegExp(
    r'(?<![\d:])([01]?\d|2[0-3])\s*:\s*([0-5]\d)(?:\s*:\s*([0-5]\d))?(?![\d:])',
  );

  static String? _date(List<ReceiptLine> lines, DateTime today) {
    String two(int v) => v.toString().padLeft(2, '0');
    final limit = today.add(const Duration(days: 1));
    for (final re in _dates) {
      for (var i = 0; i < lines.length; i++) {
        final text = _fixDigits(lines[i].text);
        for (final m in re.allMatches(text)) {
          var y = int.parse(m.group(1)!);
          if (y < 100) y += 2000;
          final mo = int.parse(m.group(2)!);
          final d = int.parse(m.group(3)!);
          // 오래된 영수증도 있다(2018년 것을 버렸었다). 2000년 앞만 버린다.
          if (y < 2000 || mo < 1 || mo > 12 || d < 1 || d > 31) continue;
          final day = DateTime(y, mo, d);
          // 2월 31일처럼 넘어간 날, 아직 안 온 날은 잘못 읽은 것이다.
          if (day.month != mo || day.isAfter(limit)) continue;
          final key = '$y-${two(mo)}-${two(d)}';
          // 시각은 날짜 뒤에 붙어 있거나 같은 높이 옆 줄에 있다.
          // ('i9:56' 처럼 1을 i 로 읽기도 한다)
          final rest = text.substring(m.end).replaceAll(RegExp(r'[iI]'), '1');
          var t = _time.firstMatch(rest);
          if (t == null) {
            for (final l in lines) {
              if (identical(l, lines[i]) || !_sameRow(l, lines[i])) continue;
              t = _time.firstMatch(l.text);
              if (t != null) break;
            }
          }
          // 시각이 다른 줄에 따로 찍힌 영수증도 있다(`10:25:42 (L)`).
          // 날짜 줄과 높이가 가장 가까운 줄의 시각을 쓴다. 여기서는 ':' 로 쓴
          // 것만 받는다 — '.' 까지 받으면 금액(15.000)을 시각으로 읽는다.
          if (t == null) {
            double bestGap = double.infinity;
            for (final l in lines) {
              final m2 = _colonTime.firstMatch(
                l.text.replaceAll(RegExp(r'(?<=\d)[iIl]|[iIl](?=\d)'), '1'),
              );
              if (m2 == null) continue;
              final gap = (l.centerY - lines[i].centerY).abs();
              if (gap < bestGap) {
                t = m2;
                bestGap = gap;
              }
            }
          }
          if (t == null) return key;
          final h = int.parse(t.group(1)!);
          final mi = int.parse(t.group(2)!);
          final s = int.tryParse(t.group(3) ?? '') ?? 0;
          return '$key ${two(h)}:${two(mi)}:${two(s)}';
        }
      }
    }
    return _dateSquashed(lines, today);
  }

  /// 구분 기호를 놓쳐 숫자가 붙어 읽힌 날짜·시각(`201611 22 1334: 19`).
  /// 빈칸을 다 빼고 `YYYYMMDD` 다음에 `HHMM(SS)` 가 오는지 본다.
  /// 달·날·시·분이 말이 되는 값일 때만 받는다.
  static String? _dateSquashed(List<ReceiptLine> lines, DateTime today) {
    String two(int v) => v.toString().padLeft(2, '0');
    final limit = today.add(const Duration(days: 1));
    final re = RegExp(
      r'(?<!\d)(20\d{2})[-./]?(0[1-9]|1[0-2])[-./]?(0[1-9]|[12]\d|3[01])',
    );
    final timeRe = RegExp(r'^([01]\d|2[0-3])[:.]?([0-5]\d)(?:[:.]?([0-5]\d))?');
    for (final l in lines) {
      final sq = _fixDigits(l.text)
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[iIl]'), '1');
      for (final m in re.allMatches(sq)) {
        final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
        final day = DateTime(y, mo, d);
        if (day.month != mo || day.isAfter(limit)) continue;
        final key = '$y-${two(mo)}-${two(d)}';
        final t = timeRe.firstMatch(sq.substring(m.end));
        if (t == null) return key;
        final s = int.tryParse(t[3] ?? '') ?? 0;
        return '$key ${t[1]}:${t[2]}:${two(s)}';
      }
    }
    return null;
  }

  // ── 업체명 ────────────────────────────────────────────────────────

  /// 앞뒤에 붙은 기호 부스러기(`:`·`|`·괄호 등)를 걷는다.
  static String _clean(String s) => s
      .replaceAll(RegExp(r'^[\s:：;|\]\)\-.,]+'), '')
      .replaceAll(RegExp(r'[\s:：;|\[\(\-.,]+$'), '')
      .trim();

  /// 이름표 줄에서 이름표 뒤 글자. 띄어 쓴 '가 맹 점 명' 도 받도록 빈칸을
  /// 빼고 세며 건넌다. 이름표가 없으면 널.
  static String? _afterKey(String t, String key) {
    final at = _squash(t).indexOf(key);
    if (at < 0) return null;
    var seen = 0;
    for (var i = 0; i < t.length; i++) {
      if (t[i].trim().isEmpty) continue;
      seen++;
      if (seen == at + key.length) return t.substring(i + 1);
    }
    return '';
  }

  /// 이름표 옆의 값 — 같은 줄 안, 없으면 같은 높이 오른쪽 줄 가운데
  /// [ok] 를 만족하고 높이가 가장 가까운 것.
  ///
  /// 오른쪽 열에는 '가맹점 번호' 값처럼 바로 위아래 줄의 값이 같은 높이로
  /// 걸리기도 한다. 그래서 첫 번째가 아니라 **가장 가까우면서 이름처럼
  /// 생긴 것**을 고른다.
  static String? _labelValue(
    ReceiptLine l,
    String rest,
    List<ReceiptLine> lines,
    bool Function(String) ok,
  ) {
    final own = _clean(rest);
    if (ok(own)) return own;
    String? best;
    double bestGap = double.infinity;
    for (final o in lines) {
      if (identical(o, l) || !_sameRow(o, l) || o.left < l.right - 4) continue;
      final v = _clean(o.text);
      if (!ok(v)) continue;
      final gap = (o.centerY - l.centerY).abs();
      if (gap < bestGap) {
        best = v;
        bestGap = gap;
      }
    }
    return best;
  }

  static String? _store(List<ReceiptLine> lines) {
    bool storeOk(String v) => _looksLikeName(v) && !_notStore.any(v.contains);

    for (final key in _storeKeys) {
      for (final l in lines) {
        final raw = _afterKey(l.text, key);
        if (raw == null) continue;
        final rest = raw.trimLeft();
        // '가맹점명, 가맹점 주소가 실제와 다른 경우 신고…' 같은 안내문 속
        // 낱말이다 — 이름표가 아니다. 이름표 뒤에는 ':' 이나 이름이 온다.
        // (토씨는 붙어 있을 때만 본다 — '가맹점명 이디야'의 '이'는 이름이다)
        if (rest.startsWith(RegExp(r'[,./·]')) ||
            raw.startsWith(RegExp(r'[과와이가은는을를의및]'))) {
          continue;
        }
        // '가맹점'·'업체'처럼 '명'이 없는 이름표는 뒤에 ':' 이 오거나 비어
        // 있을 때만 — '가맹점 번호'·'업체 전화'를 이름으로 잡지 않게.
        // '상호'는 늘 이름이 뒤따르니 ':' 없이 띄어 써도(`상호 한빛식당`) 받는다.
        if (!key.endsWith('명') &&
            !key.startsWith(RegExp(r'[상삼]')) &&
            rest.isNotEmpty &&
            !rest.startsWith(RegExp(r'[:：]'))) {
          continue;
        }
        // 같은 줄 다음 이름표 앞에서 자른다(`:한빛상회 대표자:김민수` → 한빛상회).
        final body = rest.replaceFirst(RegExp(r'^[\s:：]+'), '');
        final cut = _nextLabel.firstMatch(body);
        final own = cut == null ? body : body.substring(0, cut.start);
        final v = _labelValue(l, own, lines, storeOk);
        if (v != null) return v;
      }
    }

    // 이름표가 없으면 **영수증 머리의 큰 글씨** — 가게 이름은 사업자번호·
    // 대표자 줄 위에 크게 찍힌다('한빛식당'). 맨 윗줄을 그냥 믿지는 않는다:
    // 화면을 찍으면 브라우저 즐겨찾기 줄('YouTube 네이버…')이 맨 위에 온다.
    final head = _storeInHeader(lines, storeOk);
    if (head != null) return head;

    // 그것도 없으면 **대표자 이름**을 쓴다(사용자 요청).
    final owner = _owner(lines);
    if (owner != null) return owner;

    // 그것도 없으면 맨 위에서부터 이름처럼 생긴 첫 줄(화면 글씨는 뺀다).
    for (final l in lines.take(8)) {
      if (!_isTextLine(l) || _isScreenChrome(l.text)) continue;
      final v = _clean(l.text.replaceAll(RegExp(r'[\[\]【】<>]'), ' '));
      if (storeOk(v)) return v;
    }
    return null;
  }

  /// 가로로 누운 글자 줄인지. 세로로 길쭉한 것은 사진 귀퉁이를 잘못 읽은 것.
  static bool _isTextLine(ReceiptLine l) => l.right - l.left > l.height;

  /// 모니터를 찍었을 때 함께 찍히는 브라우저·작업표시줄 글씨.
  static bool _isScreenChrome(String t) => RegExp(
    // 뒤쪽은 펀클럽 자신의 화면 글씨 — 앱 화면을 캡처한 사진을 앨범에서 고르면 함께 읽힌다.
    r'YouTube|Google|Gemini|ChatGPT|Daum|네이[버베]|프린트시티|정부24|홈택스|photoView|http|검색|Opal|DeeVid|Claude|고용24|국세청|'
    r'항목\s*(수정|추가)|재정관리|클럽\s*[재제]정|영수증\s*(크게|다시|사진)|^\s*(취소|수정|추가|빼기)\s*$',
    caseSensitive: false,
  ).hasMatch(t);

  /// 영수증 머리(사업자번호·대표자·주소·전화 줄 위)에서 가게 이름 줄.
  ///
  /// 가게 이름은 머리에 **큰 글씨**로 찍힌다. 머리 안의 이름처럼 생긴 줄 가운데
  /// 글씨가 가장 큰 것을 고르고, 크기가 엇비슷하면 사업자번호 줄에 가까운
  /// (아래쪽) 것 — 맨 위에는 '[카드판매 영수증]' 같은 제목이 온다.
  ///
  /// '영수증' 제목 줄은 머리의 끝이 아니다. 예전에는 그 줄 위만 보다가
  /// 아무것도 못 찾아 대표자 이름('김민수')을 업체명에 넣었다.
  static String? _storeInHeader(
    List<ReceiptLine> lines,
    bool Function(String) ok,
  ) {
    final anchors = lines.where(
      // 카드사 안내 줄('가맹점주소가 실제와 다른 경우 신고…', '여신금융협회 ☎…')은
      // 가게 머리가 아니다 — 그 줄을 기준으로 잡으면 위에 아무것도 없다.
      (l) =>
          !RegExp(r'협회|신고|포상금').hasMatch(_squash(l.text)) &&
          (RegExp(r'사업자|대표|주소|전화|TEL|Tel|등록번호').hasMatch(_squash(l.text)) ||
              _bizOrPhone.hasMatch(l.text) ||
              RegExp(r'^[Tt][Ee]?[Ll]').hasMatch(l.text.trim())),
    );
    if (anchors.isEmpty) return null;
    final anchor = anchors.first;
    // 영수증 제목 줄('[카드판매 영수증]'·'[고객용]'·'IC카드승인')이 위에 있으면
    // 그 아래만 본다. 휴대폰 화면을 찍은 사진은 제목 위에 앱 글씨('항목 수정')가
    // 더 크게 찍혀 그것을 업체명으로 넣었다.
    double top = -double.infinity;
    for (final l in lines) {
      if (l.top >= anchor.top) break;
      if (RegExp(r'영수[증종]|매출전표|고객용|회원용|카드승인|카드판매')
          .hasMatch(_squash(l.text))) {
        top = math.max(top, l.top);
      }
    }
    final cands = [
      for (final l in lines)
        if (_isTextLine(l) &&
            !_isScreenChrome(l.text) &&
            l.top > top &&
            l.top < anchor.top - anchor.height * 0.3 &&
            // 머리는 사업자 줄 위 열 줄 높이 안쪽. 그보다 위는 사진에 함께
            // 찍힌 다른 글씨다.
            anchor.top - l.bottom < anchor.height * 10 &&
            ok(_clean(l.text)))
          l,
    ];
    if (cands.isEmpty) return null;
    final tallest = cands.map((l) => l.height).reduce(math.max);
    final big = cands.where((l) => l.height >= tallest * 0.85);
    final best = big.reduce((a, b) => a.bottom > b.bottom ? a : b);
    return _clean(best.text);
  }

  /// 사업자번호(123-45-67890, 빈칸·붙여 씀도) 또는 전화번호.
  static final RegExp _bizOrPhone = RegExp(
    r'\d{3}\s*-?\s*\d{2}\s*-?\s*\d{5}|0\d{1,2}[\s)\-.]*\d{3,4}[\s\-.]*\d{4}',
  );

  /// 사람 이름으로 볼 한글 두~네 글자(이름표·지명 낱말은 뺀다).
  static final RegExp _personName = RegExp(r'(?<![가-힣])[가-힣]{2,4}(?![가-힣])');
  /// 이 글자가 들어 있으면 사람 이름이 아니다('일련번호'·'카드번호' 등).
  static const List<String> _notPerson = [
    '대표',
    '사업',
    '전화',
    '번호',
    '주소',
    '서울',
    '특별',
    '광역',
    '등록',
    '매장',
    '매입',
    '가맹',
    '영수',
    '테이블',
    '고객',
    '카드',
    '승인',
    '금액',
    '일시',
  ];
  static bool _isPerson(String v) =>
      _personName.firstMatch(v)?[0] == v && !_notPerson.any(v.contains);

  /// 대표자 이름. '대표자' 이름표가 있으면 그 값, 없으면 사업자번호·전화번호와
  /// 같은 줄에 적힌 한글 이름(영수증 머리에 `사업자번호 TEL 이름` 꼴로 적힌다).
  static String? _owner(List<ReceiptLine> lines) {
    for (final key in _ownerKeys) {
      for (final l in lines) {
        final raw = _afterKey(l.text, key);
        if (raw == null) continue;
        final v = _labelValue(l, raw, lines, _isPerson);
        if (v != null) return v;
      }
    }
    for (final l in lines) {
      if (!_bizOrPhone.hasMatch(l.text)) continue;
      // 카드 영수증 머리의 '여신금융협회 ☎(02)2011-0777 -포상금 10만원 지급'
      // 같은 안내 줄은 가게 줄이 아니다('포상금'을 업체명에 넣었다).
      if (RegExp(r'협회|신고|포상금|고객센터|상담').hasMatch(_squash(l.text))) {
        continue;
      }
      final rest = l.text.replaceAll(_bizOrPhone, ' ');
      for (final m in _personName.allMatches(rest)) {
        if (_isPerson(m[0]!)) return m[0];
      }
    }
    return null;
  }

  /// 글자가 두 자 이상이고 숫자투성이가 아닌 것.
  static bool _looksLikeName(String v) {
    if (v.length < 2 || v.length > 30) return false;
    final letters = RegExp(r'[가-힣A-Za-z]').allMatches(v).length;
    final digits = RegExp(r'\d').allMatches(v).length;
    return letters >= 2 && digits <= letters;
  }
}

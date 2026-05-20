import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 점수 입력 후 승자팀이 서명하는 단순 캔버스 + 다이얼로그.
///
/// 외부 패키지 없이 CustomPaint + GestureDetector 로 구현.
/// PNG 로 export → base64 data URL 반환 — Firestore 문서에 그대로 저장 가능.

class SignaturePad extends StatefulWidget {
  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  const SignaturePad({
    super.key,
    this.width = 320,
    this.height = 160,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.5,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];

  bool get hasInk => _strokes.any((s) => s.length > 1);

  void clear() => setState(() => _strokes.clear());

  /// PNG data URL 로 export — 다이얼로그 확인 버튼이 호출.
  /// 서명이 비었으면 빈 문자열 반환.
  /// 자동 크롭: 사용자가 캔버스의 일부 영역에만 그렸을 때 빈 공간 제거하여
  /// 저장 시점에 서명이 꽉 차도록 한다 (보기 다이얼로그에서 좌우 여백 방지).
  Future<String> exportPng() async {
    if (!hasInk) return '';

    // 모든 strokes 의 bounding box 계산.
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final stroke in _strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    // stroke width 만큼 여백 확보 + 작은 패딩.
    final padding = widget.strokeWidth + 6;
    minX = (minX - padding).clamp(0.0, widget.width);
    minY = (minY - padding).clamp(0.0, widget.height);
    maxX = (maxX + padding).clamp(0.0, widget.width);
    maxY = (maxY + padding).clamp(0.0, widget.height);
    final cropW = (maxX - minX).clamp(1.0, widget.width);
    final cropH = (maxY - minY).clamp(1.0, widget.height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, cropW, cropH),
    );
    // 흰 배경.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cropW, cropH),
      Paint()..color = Colors.white,
    );
    // 캔버스 원점을 (minX, minY) 만큼 이동시켜 strokes 가 cropped 영역에 그려지게.
    canvas.translate(-minX, -minY);
    final paint = Paint()
      ..color = widget.strokeColor
      ..strokeWidth = widget.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(cropW.toInt(), cropH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return '';
    final bytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          setState(() => _strokes.add([d.localPosition]));
        },
        onPanUpdate: (d) {
          if (_strokes.isEmpty) return;
          // 캔버스 영역 밖으로 나가는 점은 잘라냄.
          final p = d.localPosition;
          if (p.dx < 0 || p.dy < 0 ||
              p.dx > widget.width || p.dy > widget.height) {
            return;
          }
          setState(() => _strokes.last.add(p));
        },
        onPanEnd: (_) {},
        child: CustomPaint(
          painter: _SigPainter(
            strokes: _strokes,
            color: widget.strokeColor,
            width: widget.strokeWidth,
          ),
          size: Size(widget.width, widget.height),
        ),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double width;
  _SigPainter({
    required this.strokes,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, width / 2, paint..style = PaintingStyle.fill);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}

/// 저장된 서명을 보여주는 다이얼로그. 반환: true 면 사용자가 "다시 서명" 선택,
/// false / null 이면 단순 닫기.
Future<bool> showSavedSignatureDialog(
  BuildContext context, {
  required String signatureDataUrl,
  required int scoreA,
  required int scoreB,
  required String winnerSide,
  required String winnerLabel,
}) async {
  // data URL prefix 제거 후 base64 decode.
  final prefix = 'base64,';
  final idx = signatureDataUrl.indexOf(prefix);
  final b64 = idx >= 0
      ? signatureDataUrl.substring(idx + prefix.length)
      : signatureDataUrl;
  Uint8List? bytes;
  try {
    bytes = base64Decode(b64);
  } catch (_) {}

  final reSign = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // 회전 transient / 작은 viewport 에서 content+actions 합산이 다이얼로그
      // max height 초과 → BOTTOM OVERFLOWED. scrollable: true 로 자동 scroll wrap
      // 해 어떤 viewport 에서도 overflow 시각화 불가. (입력용 다이얼로그는
      // 별도 SingleChildScrollView 로 동일 안전망 보유.)
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          const Expanded(
            child: Text('저장된 서명',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: '닫기',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('승리: $winnerLabel (팀$winnerSide)',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A))),
          Text('스코어: $scoreA : $scoreB',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (bytes != null)
            // PNG 는 사용자 strokes 의 bounding box 로 자동 크롭되어 가변 비율.
            // 고정 height + BoxFit.contain 으로 가운데 정렬, 빈 공간 최소화.
            SizedBox(
              height: 140,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            )
          else
            const Text('서명 이미지를 불러올 수 없습니다.',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('다시 서명'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
  return reSign == true;
}

/// 승자 서명 다이얼로그.
/// 반환: (signaturePng, winnerSide).
/// - 서명+확인 → ('data:image/png;base64,...', side)
/// - 건너뛰기 → ('', side) — 점수는 저장하지만 서명 없이
/// - 다이얼로그 dismiss / 취소 → null (저장 자체 취소)
class WinnerSignatureResult {
  final String signature; // PNG data URL or ''
  final String winnerSide; // 'A' | 'B' | ''
  const WinnerSignatureResult(this.signature, this.winnerSide);
}

Future<WinnerSignatureResult?> showWinnerSignatureDialog(
  BuildContext context, {
  required int scoreA,
  required int scoreB,
  required String teamALabel,
  required String teamBLabel,
}) async {
  // 승자 판정. 무승부면 빈 side — 서명 면제하고 빈 결과 즉시 반환.
  String winnerSide;
  String winnerLabel;
  if (scoreA > scoreB) {
    winnerSide = 'A';
    winnerLabel = teamALabel;
  } else if (scoreB > scoreA) {
    winnerSide = 'B';
    winnerLabel = teamBLabel;
  } else {
    return const WinnerSignatureResult('', '');
  }

  final padKey = GlobalKey<SignaturePadState>();

  final result = await showDialog<WinnerSignatureResult?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      // 회전 transient frame 에 dialog 영역이 매우 작아진 viewport (예: h=84.5) 를
      // 받으면 어떤 padding 조정도 부족 — insetPadding 을 거의 0 으로 두어 dialog 가
      // viewport 전체를 차지하게 만든 게 어떤 transient 에서도 SignaturePad fit 보장.
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Row(
        children: [
          const Expanded(
            child: Text('승자팀 서명',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: '닫기',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(ctx, null),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      content: Builder(builder: (ctx) {
        // 가로 모드 (점수판 안에서 띄울 때) 는 viewport 의 height 가 좁아 기본
        // SignaturePad height(160) 가 overflow 일으킴. 화면 비율 따라 동적 조정.
        // (LayoutBuilder 는 AlertDialog 의 IntrinsicWidth 와 충돌해 freeze → Builder.)
        final mq = MediaQuery.of(ctx);
        final isLandscape = mq.orientation == Orientation.landscape;
        // SingleChildScrollView 로 wrap 시 SignaturePad 의 pan gesture 가 scroll 의
        // vertical drag 에 잡혀 그리기 안 됨 → scroll 제거. 작은 viewport 는
        // padHeight 을 보수적으로 줄여 overflow 발생 자체 차단.
        final padHeight = isLandscape
            ? (mq.size.height * 0.32).clamp(100.0, 160.0)
            : 200.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('승리: $winnerLabel',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A))),
            Text('스코어: $scoreA : $scoreB',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SignaturePad(key: padKey, height: padHeight.toDouble()),
            const SizedBox(height: 4),
            const Text('* 패자팀은 서명 면제',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        );
      }),
      actions: [
        TextButton(
          onPressed: () => padKey.currentState?.clear(),
          child: const Text('지우기'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, WinnerSignatureResult('', winnerSide)),
          child: const Text('건너뛰기'),
        ),
        FilledButton(
          onPressed: () async {
            final png = await padKey.currentState?.exportPng() ?? '';
            if (ctx.mounted) {
              Navigator.pop(ctx, WinnerSignatureResult(png, winnerSide));
            }
          },
          child: const Text('서명 완료'),
        ),
      ],
    ),
  );
  return result;
}

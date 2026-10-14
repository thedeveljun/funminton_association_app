// lib/services/receipt/receipt_scanner_io.dart
//
// 폰용 영수증 스캐너 — 펀클럽(funminton_club_app) ReceiptScanner 를 옮겨 왔다.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'receipt_parser.dart';

/// 영수증 사진을 찍거나 골라 **이 폰에 보관**하고, 글자를 읽어
/// [ReceiptInfo] 로 돌려준다.
///
/// 글자 읽기는 **폰 안에서** 한다(구글 ML Kit 한글 모델) — 사진이 밖으로
/// 나가지 않고 인터넷도 필요 없다.
///
/// 사진은 앱 문서 폴더의 `receipts/` 에 둔다(사진기 임시 폴더는 폰이 비운다).
/// 장부 항목에는 그 경로만 적는다.
class ReceiptScanner {
  /// 이 기기에서 영수증 사진을 쓸 수 있는지.
  static bool get supported => true;

  /// 찍기/고르기 창을 띄워 사진을 보관하고 그 경로를 돌려준다. 그만두면 널.
  static Future<String?> pickPhoto(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('영수증 사진 찍기', maxLines: 1, softWrap: false),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('앨범에서 고르기', maxLines: 1, softWrap: false),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;

    // 2400px·품질 85. 더 줄이면 구겨진 감열지 글자를 많이 틀린다.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (file == null) return null;

    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/receipts');
    await dir.create(recursive: true);
    final dest = '${dir.path}/r_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(file.path).copy(dest);
    return dest;
  }

  /// 보관한 사진의 글자를 읽어 업체명·날짜·금액·전화번호를 고른다.
  static Future<ReceiptInfo> read(String path) async {
    final lines = await readLines(path);
    final info = ReceiptParser.parse(lines);
    if (kDebugMode) {
      for (final l in lines) {
        debugPrint('[RCPT] ${l.left.round()},${l.top.round()},'
            '${l.right.round()},${l.bottom.round()} | ${l.text}');
      }
      debugPrint('[RCPT] => $info');
    }
    return info;
  }

  /// 사진의 글자 줄을 읽어, 기운 사진을 바로 편 자리로 돌려준다.
  static Future<List<ReceiptLine>> readLines(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final read =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return straightenReceipt([
        for (final b in read.blocks)
          for (final l in b.lines)
            ReceiptQuad(l.text, [
              for (final p in l.cornerPoints)
                math.Point(p.x.toDouble(), p.y.toDouble()),
            ]),
      ]);
    } finally {
      recognizer.close();
    }
  }

  /// 보관한 영수증 사진을 지운다. `receipts/` 밖의 파일은 건드리지 않는다.
  static Future<void> deletePhoto(String? path) async {
    if (path == null || !path.replaceAll('\\', '/').contains('/receipts/r_')) {
      return;
    }
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 작은 사진. 파일이 없으면 [fallback] 을 그린다.
  static Widget thumb(String path,
      {required double size, required Widget fallback}) {
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 3.5).round(),
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  /// 영수증 사진을 화면 가득 띄운다. 두 손가락으로 키워 볼 수 있다.
  static Future<void> view(BuildContext context, String path) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(path),
              errorBuilder: (_, __, ___) => const Text(
                '이 폰에는 영수증 사진이 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

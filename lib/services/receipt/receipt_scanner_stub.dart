// lib/services/receipt/receipt_scanner_stub.dart
//
// 웹(Chrome)용 대체본. 사진 파일·ML Kit 를 쓸 수 없어 영수증 기능을 끈다.

import 'package:flutter/material.dart';

import 'receipt_parser.dart';

class ReceiptScanner {
  static bool get supported => false;

  static Future<String?> pickPhoto(BuildContext context) async => null;

  static Future<ReceiptInfo> read(String path) async =>
      ReceiptParser.parse(const []);

  static Future<void> deletePhoto(String? path) async {}

  static Widget thumb(String path,
          {required double size, required Widget fallback}) =>
      fallback;

  static Future<void> view(BuildContext context, String path) async {}
}

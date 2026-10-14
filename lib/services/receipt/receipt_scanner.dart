// lib/services/receipt/receipt_scanner.dart
//
// 영수증 사진 찍기·글자 읽기·보관·보기.
// 폰(dart:io)에서는 ML Kit 로 읽고, 웹에서는 사진 기능이 없는 대체본을 쓴다.

export 'receipt_scanner_stub.dart'
    if (dart.library.io) 'receipt_scanner_io.dart';

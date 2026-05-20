import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Activity-level orientation lock — Flutter SystemChrome 의 hint 가
/// OS sensor 에 묻히는 race 회피용. ScoreboardPage 진입/종료 시 호출.
class OrientationService {
  static const _channel = MethodChannel(
      'com.develogic.funminton_bracket/orientation');

  /// Activity 를 landscape 로 강제. sensor 기반 (left/right 둘 다 허용).
  static Future<void> lockLandscape() async {
    if (kIsWeb || !defaultTargetPlatform.toString().contains('android')) return;
    try {
      await _channel.invokeMethod('lockLandscape');
    } catch (e) {
      debugPrint('[OrientationService] lockLandscape failed: $e');
    }
  }

  /// Activity 를 portrait 로 강제. sensor 무관.
  static Future<void> lockPortrait() async {
    if (kIsWeb || !defaultTargetPlatform.toString().contains('android')) return;
    try {
      await _channel.invokeMethod('lockPortrait');
    } catch (e) {
      debugPrint('[OrientationService] lockPortrait failed: $e');
    }
  }

  /// Activity orientation 해제 — 시스템 기본.
  static Future<void> unlock() async {
    if (kIsWeb || !defaultTargetPlatform.toString().contains('android')) return;
    try {
      await _channel.invokeMethod('unlock');
    } catch (e) {
      debugPrint('[OrientationService] unlock failed: $e');
    }
  }
}

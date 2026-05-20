import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/models/saved_match_record.dart';
import 'package:badminton_association/score/widgets/share_match_card.dart';

/// 경기 기록을 텍스트 + 점수판 카드 이미지로 시스템 공유 시트에 공유.
/// 카카오톡/문자/Line/WeChat 등 사용자가 설치한 모든 앱이 공유 시트에 자동 노출됨.
class ShareMatch {
  static Future<void> share({
    required BuildContext context,
    required SavedMatchRecord record,
    required S s,
  }) async {
    final shareText = _composeShareText(record, s);

    Uint8List? imageBytes;
    try {
      final controller = ScreenshotController();
      imageBytes = await controller.captureFromWidget(
        ShareMatchCard(record: record, s: s),
        pixelRatio: 1.5,
        delay: const Duration(milliseconds: 50),
        context: context,
        targetSize: const Size(1080, 1080),
      );
    } catch (_) {
      imageBytes = null;
    }

    if (imageBytes != null) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            imageBytes,
            name: 'badminton_match.png',
            mimeType: 'image/png',
          ),
        ],
        text: shareText,
        subject: s.shareSubject,
      );
    } else {
      await Share.share(shareText, subject: s.shareSubject);
    }
  }

  static String _composeShareText(SavedMatchRecord r, S s) {
    final left =
        '${s.localizedPlayerName(r.leftPlayer1)}/${s.localizedPlayerName(r.leftPlayer2)}';
    final right =
        '${s.localizedPlayerName(r.rightPlayer1)}/${s.localizedPlayerName(r.rightPlayer2)}';
    final dateLine = _formatDate(r.savedAt);
    return '🏸 ${s.appTitle}\n$left  vs  $right\n${r.scoreA} : ${r.scoreB}\n$dateLine';
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return iso;
    }
  }
}

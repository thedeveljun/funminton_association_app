import 'package:flutter/material.dart';

/// 폼 화면 하단 공용 [취소][등록/저장] 버튼 바
///
/// 사용법:
/// ```dart
/// Scaffold(
///   ...
///   bottomNavigationBar: FormActionBar(
///     onCancel: () => Navigator.pop(context),
///     onSubmit: () => _save(),
///     submitLabel: '등록',  // 또는 '저장'
///   ),
/// )
/// ```
class FormActionBar extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final String cancelLabel;
  final String submitLabel;
  final bool submitEnabled;

  const FormActionBar({
    super.key,
    this.onCancel,
    required this.onSubmit,
    this.cancelLabel = '취소',
    this.submitLabel = '등록',
    this.submitEnabled = true,
  });

  static const _primary = Color(0xFF2563EB);
  static const _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: _border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // ── 취소 버튼 ──────────────────
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: onCancel ?? () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    cancelLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── 등록/저장 버튼 ─────────────
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: submitEnabled ? onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withOpacity(0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    submitLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:badminton_association/score/l10n/app_locale.dart';
import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/l10n/locale_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 부모(점수판)와 동일하게 가로모드 유지 — 회전 전환을 일으키지 않음으로써
  // 자동복귀 시 LayoutBuilder가 중간 크기로 잠기는 버그 회피.

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: LocaleController.notifier,
      builder: (context, currentLocale, _) {
        final s = S(currentLocale);
        // 노출 언어 + 표시 순서: 한국어 → 영어 → 중국어 → 일본어.
        const locales = [
          AppLocale.ko,
          AppLocale.en,
          AppLocale.zh,
          AppLocale.ja,
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.4,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black),
            titleSpacing: 0,
            title: Text(
              s.settingsTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text(
                        s.languageLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEDEFF2),
                          width: 1,
                        ),
                      ),
                      // 1열 4행 스택 — 박스 사이 간격 좁힘.
                      child: Column(
                        children: [
                          for (int i = 0; i < locales.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: SizedBox(
                                height: 44,
                                child: _languageTile(
                                  locale: locales[i],
                                  selected: locales[i] == currentLocale,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _languageTile({required AppLocale locale, required bool selected}) {
    return Material(
      color: selected ? const Color(0xFFE3F0FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await LocaleController.setLocale(locale);
          if (!mounted) return;
          Navigator.pop(context);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFE4E7EB),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  locale.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF1565C0)
                        : Colors.black87,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    color: Color(0xFF1565C0), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

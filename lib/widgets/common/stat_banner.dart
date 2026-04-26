import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatBanner extends StatelessWidget {
  final List<StatItem> items;
  final Color bgColor;

  const StatBanner({
    super.key,
    required this.items,
    this.bgColor = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: bgColor,
        child: Row(
          children: items
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: e.key < items.length - 1
                            ? const Border(
                                right: BorderSide(color: Colors.white12))
                            : null,
                      ),
                      child: Column(children: [
                        Text(e.value.value,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(e.value.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(.75))),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      );
}

class StatItem {
  final String value;
  final String label;
  const StatItem(this.value, this.label);
}

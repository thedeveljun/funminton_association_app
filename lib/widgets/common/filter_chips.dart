import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final EdgeInsets? padding;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.white,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: options.map((opt) {
              final isOn = opt == selected;
              final isAll = opt == '전체';
              final bg = isAll
                  ? const Color(0xFFE8EDF5)
                  : (isOn ? AppColors.blue2 : AppColors.gray);
              final fg = isAll
                  ? AppColors.text2
                  : (isOn ? AppColors.white : AppColors.text2);
              final borderColor = isAll
                  ? (isOn ? AppColors.blue2 : Colors.transparent)
                  : (isOn ? AppColors.blue2 : Colors.transparent);
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

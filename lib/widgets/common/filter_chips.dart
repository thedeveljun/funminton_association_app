import 'package:flutter/material.dart';

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
        color: Colors.white,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: options.map((opt) {
              final isOn = opt == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: GestureDetector(
                  onTap: () => onSelect(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOn
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isOn
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFBFDBFE),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
                        color: isOn ? Colors.white : const Color(0xFF2563EB),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

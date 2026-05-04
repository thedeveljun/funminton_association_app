import 'package:flutter/material.dart';

Color gradePastelBg(String grade) {
  switch (grade) {
    case 'A조':
      return const Color(0xFFDBEAFE);
    case 'B조':
      return const Color(0xFFD1FAE5);
    case 'C조':
      return const Color(0xFFFEF3C7);
    case 'D조':
      return const Color(0xFFFFE4E6);
    case '초심조':
      return const Color(0xFFF3E8FF);
    case 'S조':
      return const Color(0xFFE0F2FE);
    default:
      return const Color(0xFFF1F5F9);
  }
}

Color gradePastelFg(String grade) {
  switch (grade) {
    case 'A조':
      return const Color(0xFF1E40AF);
    case 'B조':
      return const Color(0xFF065F46);
    case 'C조':
      return const Color(0xFF92400E);
    case 'D조':
      return const Color(0xFF9F1239);
    case '초심조':
      return const Color(0xFF6B21A8);
    case 'S조':
      return const Color(0xFF075985);
    default:
      return const Color(0xFF6B7A99);
  }
}

class GradePastelChip extends StatelessWidget {
  final String grade;
  const GradePastelChip(this.grade, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: gradePastelBg(grade),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          grade,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: gradePastelFg(grade),
          ),
        ),
      );
}

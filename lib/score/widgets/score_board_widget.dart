import 'package:flutter/material.dart';

class ScoreBoardWidget extends StatelessWidget {
  final int score;
  final bool isServingTeam;
  final int targetScore;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ScoreBoardWidget({
    super.key,
    required this.score,
    required this.isServingTeam,
    required this.targetScore,
    required this.onTap,
    required this.onLongPress,
  });

  bool get _activeBorder => isServingTeam && score >= 1;

  Color _scoreTextColor() {
    const brightOrange = Color(0xFFFF8C00);
    if (targetScore == 15 && score >= 8) return brightOrange;
    if (targetScore == 21 && score >= 11) return brightOrange;
    if (targetScore == 25 && score >= 13) return brightOrange;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _activeBorder
                ? const Color(0xFF66DD00)
                : const Color(0xFF585858),
            width: 4,
          ),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3E3E3E),
              Color(0xFF1F1F1F),
              Color(0xFF101010),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0,
                    child: Text(
                      '88',
                      style: TextStyle(
                        fontSize: 320,
                        fontWeight: FontWeight.w900,
                        color: _scoreTextColor(),
                        height: 0.9,
                      ),
                    ),
                  ),
                  Text(
                    '$score',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 320,
                      fontWeight: FontWeight.w900,
                      color: _scoreTextColor(),
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

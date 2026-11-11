import 'package:flutter/material.dart';

import '../theme.dart';

class LetterAvatar extends StatelessWidget {
  const LetterAvatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.avatarFor(name),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          letter,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.43),
        ),
      ),
    );
  }
}

/// Mała etykieta „APP” / „WWW” przy haśle.
class KindTag extends StatelessWidget {
  const KindTag.app({super.key})
      : label = 'APP',
        tooltip = 'Przypisane do aplikacji',
        background = AppColors.passwordsSoft,
        foreground = const Color(0xFF1F4AB8);
  const KindTag.web({super.key})
      : label = 'WWW',
        tooltip = 'Przypisane do strony',
        background = const Color(0xFFEEF0F4),
        foreground = const Color(0xFF3F4654);

  final String label;
  final String tooltip;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground)),
      ),
    );
  }
}

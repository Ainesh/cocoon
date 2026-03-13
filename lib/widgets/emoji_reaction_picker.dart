library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/memory.dart';
import '../theme/app_colors.dart';

class EmojiReactionPicker extends StatelessWidget {
  const EmojiReactionPicker({super.key, this.selectedEmoji, required this.onSelected});

  final String? selectedEmoji;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final option in MemoryReactions.options)
          _buildButton(option.emoji),
      ],
    );
  }

  Widget _buildButton(String emoji) {
    final active = selectedEmoji == emoji;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onSelected(emoji);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? AppColors.accentRed.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.accentRed.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(emoji, style: TextStyle(fontSize: active ? 28 : 24)),
      ),
    );
  }
}

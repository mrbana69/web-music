import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodChipsBar extends StatelessWidget {
  final List<Map<String, String>> chips;
  final String? selectedParam;
  final ValueChanged<Map<String, String>?> onChipSelected;

  const MoodChipsBar({
    super.key,
    required this.chips,
    this.selectedParam,
    required this.onChipSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          final title = chip['title'] ?? '';
          final params = chip['params'];
          final isSelected = selectedParam != null && selectedParam == params;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isSelected) {
                    onChipSelected(null);
                  } else {
                    onChipSelected(chip);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.surfaceContainerHigh.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      title,
                      style: AppTheme.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


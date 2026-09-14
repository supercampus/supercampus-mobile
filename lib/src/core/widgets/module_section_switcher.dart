import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ModuleSection {
  const ModuleSection({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Shared in-module section control.
///
/// It deliberately lives in page content instead of the bottom navigation
/// lane. The official campus navigation remains the only docked app bar.
class ModuleSectionSwitcher extends StatelessWidget {
  const ModuleSectionSwitcher({
    super.key,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECEF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (var index = 0; index < sections.length; index++)
                Expanded(
                  child: _SectionButton(
                    section: sections[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final ModuleSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: section.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                section.icon,
                size: 17,
                color: selected ? AppColors.brandBlue : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.ink : AppColors.muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

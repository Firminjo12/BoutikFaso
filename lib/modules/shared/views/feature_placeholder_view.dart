import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';

class FeaturePlaceholderView extends StatelessWidget {
  const FeaturePlaceholderView({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SectionCard(
              title: title,
              subtitle: 'Espace de travail',
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  const Chip(
                    avatar: Icon(Icons.construction_outlined, size: 16),
                    label: Text('À construire selon le planning'),
                    backgroundColor: AppColors.surfaceTint,
                    side: BorderSide.none,
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

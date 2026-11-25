import 'package:flutter/material.dart';
import '../../core/theme/ryu_colors.dart';

/// Honest empty state: shown until real data exists. No fake content.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RyuColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: RyuColors.violet),
          const SizedBox(width: 16),
          Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: RyuColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

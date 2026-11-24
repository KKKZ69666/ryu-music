import 'package:flutter/material.dart';
import '../../core/theme/ryu_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!,
                  style: t.bodySmall?.copyWith(color: RyuColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

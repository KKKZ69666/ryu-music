import 'package:flutter/material.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/mini_player.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../search/search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <_Tab>[
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('Search', Icons.search_rounded, Icons.search_rounded),
    _Tab('Library', Icons.library_music_outlined, Icons.library_music_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), SearchScreen(), LibraryScreen()],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GlassContainer(
                  borderRadius: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: _NavItem(
                            tab: _tabs[i],
                            selected: i == _index,
                            onTap: () => setState(() => _index = i),
                          ),
                        ),
                    ],
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

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? RyuColors.violet.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? tab.activeIcon : tab.icon,
              color: selected ? Colors.white : RyuColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : RyuColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

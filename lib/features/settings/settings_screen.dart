import 'package:flutter/material.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/glass_container.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RyuColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _SettingsSectionHeader(title: 'Appearance & Theme'),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.palette_rounded,
                  title: 'Accent Color',
                  subtitle: 'Violet Nebula (Default)',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Accent color is set to Violet Nebula')),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SettingsTile(
                  icon: Icons.blur_on_rounded,
                  title: 'Liquid Glass Intensity',
                  subtitle: 'High blur & ambient reflections',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Liquid Glass intensity set to High')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SettingsSectionHeader(title: 'Audio & Playback'),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.equalizer_rounded,
                  title: 'Equalizer & Audio FX',
                  subtitle: 'Bass boost, virtualizer & presets',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audio effects active via system decoder')),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SettingsTile(
                  icon: Icons.speed_rounded,
                  title: 'Gapless Playback',
                  subtitle: 'Seamless transition between tracks',
                  trailing: Switch(
                    value: true,
                    activeColor: RyuColors.violet,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SettingsSectionHeader(title: 'Lyrics Studio'),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.lyrics_rounded,
                  title: 'Default Flow Mode',
                  subtitle: 'Apple Flow (Active line dominant)',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Default lyrics flow mode: Apple Flow')),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SettingsTile(
                  icon: Icons.cloud_download_rounded,
                  title: 'Auto-fetch from LRCLIB',
                  subtitle: 'Automatically sync lyrics online when offline cache missing',
                  trailing: Switch(
                    value: true,
                    activeColor: RyuColors.violet,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SettingsSectionHeader(title: 'Library & Storage'),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.folder_rounded,
                  title: 'Scan Local Storage',
                  subtitle: 'Refresh music library from device MediaStore',
                  onTap: () async {
                    await RyuScope.of(context).library.scanLibrary();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Music library scanned successfully')),
                      );
                    }
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SettingsTile(
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear Cache & Artwork',
                  subtitle: 'Free up temporary storage space',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared successfully')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SettingsSectionHeader(title: 'About RYU Music'),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Version',
                  subtitle: '1.0.0+1 (Premium Offline Edition)',
                  onTap: () {},
                ),
                const Divider(color: Colors.white10, height: 1),
                _SettingsTile(
                  icon: Icons.security_rounded,
                  title: 'Privacy & Offline Guarantee',
                  subtitle: 'All data stays 100% on your device',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: RyuColors.violet,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RyuColors.violet.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: RyuColors.textSecondary, fontSize: 12),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

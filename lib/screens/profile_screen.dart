import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth/auth_controller.dart';
import '../models/user.dart';
import '../theme/color_tokens.dart';
import '../widgets/app_avatar.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _ProfileAppBar(user: user),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _ProfileSummaryCard(user: user),
                  const SizedBox(height: 20),
                  const _HighlightsRow(),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Account Controls',
                    tiles: [
                      _SettingsTileData(
                        icon: Icons.person_outline,
                        title: 'Profile details',
                        subtitle: 'Update name, headline, and avatar',
                        onTap: () {},
                      ),
                      _SettingsTileData(
                        icon: Icons.shield_moon_outlined,
                        title: 'Security center',
                        subtitle: 'Sessions, devices, multi-factor auth',
                        onTap: () {},
                      ),
                      _SettingsTileData(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Mentions, keywords, and digests',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Workspace',
                    tiles: [
                      _SettingsTileData(
                        icon: Icons.palette_outlined,
                        title: 'Theme & appearance',
                        subtitle: 'Light, dark, and accessibility options',
                        onTap: () {},
                      ),
                      _SettingsTileData(
                        icon: Icons.language_outlined,
                        title: 'Language & locale',
                        subtitle: 'Date formats, time zone, translations',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SupportPanel(onSignOut: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/auth');
                    }
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final status = user.statusMessage?.isNotEmpty == true
        ? user.statusMessage!
        : 'Crafting delightful customer experiences';

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 260,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.fadeTitle,
          StretchMode.zoomBackground,
        ],
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 24, bottom: 16),
        title: const Text('Account'),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4E5FF8), Color(0xFF1B1E4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: 40,
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.messenger_rounded,
                  size: 160,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppAvatar(
                    imageUrl: user.avatarUrl,
                    initials:
                        user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    size: 82,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 38,
            offset: Offset(0, 20),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SummaryMetric(
                label: 'Teams',
                value: '03',
                icon: Icons.group_outlined,
              ),
              const SizedBox(width: 16),
              _SummaryMetric(
                label: 'Active devices',
                value: '4',
                icon: Icons.devices_other_outlined,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Account status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Verified • MFA enabled',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Personal workspace',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your profile settings, security posture, and workspace preferences from a single dashboard.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white;

    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 12),
            color: Color(0x0F4E5FF8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightsRow extends StatelessWidget {
  const _HighlightsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _HighlightCard(
            title: 'Profile completion',
            statistic: '92%',
            accentColor: AppColors.primary,
            subtitle: 'Finish uploading a cover image',
            icon: Icons.track_changes_outlined,
          ),
          SizedBox(width: 16),
          _HighlightCard(
            title: 'Inbox uptime',
            statistic: '99.9%',
            accentColor: AppColors.success,
            subtitle: 'No incidents detected this week',
            icon: Icons.auto_graph_outlined,
          ),
          SizedBox(width: 16),
          _HighlightCard(
            title: 'Data export',
            statistic: 'Available',
            accentColor: AppColors.warning,
            subtitle: 'Schedule a compliance export',
            icon: Icons.cloud_download_outlined,
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.statistic,
    required this.accentColor,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String statistic;
  final Color accentColor;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white;

    return Container(
      width: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 12),
            color: Color(0x0F4E5FF8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statistic,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.tiles});

  final String title;
  final List<_SettingsTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, 14),
                color: Color(0x11000000),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                _SettingsTile(data: tiles[i]),
                if (i != tiles.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 68,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTileData {
  const _SettingsTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.data});

  final _SettingsTileData data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          gradient: AppColors.subtleGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(data.icon, color: AppColors.primary),
      ),
      title: Text(
        data.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        data.subtitle,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: data.onTap,
    );
  }
}

class _SupportPanel extends StatelessWidget {
  const _SupportPanel({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF0FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            offset: Offset(0, 18),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support & trust',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Need guidance?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Our success engineers respond within the same business day for workspace admins.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open support chat'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  onPressed: onSignOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

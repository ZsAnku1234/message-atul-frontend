import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../features/auth/auth_controller.dart';
import '../models/user.dart';
import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';
import '../widgets/app_avatar.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  late TextEditingController _nameController;
  String? _errorMessage;
  String? _tempAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _isUploadingAvatar = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      
      // Read image bytes for web compatibility
      final bytes = await image.readAsBytes();
      final fileName = image.name;
      
      final formData = FormData.fromMap({
        'files': MultipartFile.fromBytes(
          bytes,
          filename: fileName.isEmpty ? 'avatar.jpg' : fileName,
        ),
      });

      final response = await dio.post('/media/avatar', data: formData);
      final avatarUrl = response.data['avatarUrl'] as String;

      if (!mounted) return;

      setState(() {
        _tempAvatarUrl = avatarUrl;
        _isUploadingAvatar = false;
      });
    } catch (error) {
      if (!mounted) return;
      
      String errorMsg = 'Failed to upload image. Please try again.';
      if (error is DioException) {
        if (error.response?.data != null) {
          final data = error.response!.data;
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'].toString();
          }
        } else if (error.message != null) {
          errorMsg = 'Network error: ${error.message}';
        }
      }
      
      print('Avatar upload error: $error');
      
      setState(() {
        _isUploadingAvatar = false;
        _errorMessage = errorMsg;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() {
        _errorMessage = 'Display name cannot be empty';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    print('Saving profile with avatarUrl: $_tempAvatarUrl');
    
    final success = await ref.read(authControllerProvider.notifier).updateProfile(
          displayName: newName,
          avatarUrl: _tempAvatarUrl,
        );

    print('Profile save result: $success');
    
    if (!mounted) return;

    if (success) {
      // Get the updated user to verify
      final updatedUser = ref.read(authControllerProvider).user;
      print('Updated user avatar: ${updatedUser?.avatarUrl}');
    }

    setState(() {
      _isSaving = false;
      if (success) {
        _isEditing = false;
        _tempAvatarUrl = null;
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to update profile. Please try again.';
      }
    });
  }

  void _cancelEdit() {
    final user = ref.read(authControllerProvider).user;
    setState(() {
      _isEditing = false;
      _errorMessage = null;
      _tempAvatarUrl = null;
      _nameController.text = user?.displayName ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
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
          _ProfileAppBar(
            user: user,
            isEditing: _isEditing,
            isSaving: _isSaving,
            isUploadingAvatar: _isUploadingAvatar,
            tempAvatarUrl: _tempAvatarUrl,
            nameController: _nameController,
            errorMessage: _errorMessage,
            onEditToggle: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _nameController.text = user.displayName;
                  _tempAvatarUrl = null;
                  _errorMessage = null;
                }
              });
            },
            onPickAvatar: _pickAndUploadAvatar,
            onSave: _saveProfile,
            onCancel: _cancelEdit,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _SupportPanel(onSignOut: () async {
                    final router = GoRouter.of(context);
                    await ref.read(authControllerProvider.notifier).signOut();
                    router.go('/auth');
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
  const _ProfileAppBar({
    required this.user,
    required this.isEditing,
    required this.isSaving,
    required this.isUploadingAvatar,
    required this.tempAvatarUrl,
    required this.nameController,
    required this.onEditToggle,
    required this.onPickAvatar,
    required this.onSave,
    required this.onCancel,
    this.errorMessage,
  });

  final UserProfile user;
  final bool isEditing;
  final bool isSaving;
  final bool isUploadingAvatar;
  final String? tempAvatarUrl;
  final TextEditingController nameController;
  final VoidCallback onEditToggle;
  final VoidCallback onPickAvatar;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final status = user.statusMessage?.isNotEmpty == true
        ? user.statusMessage!
        : 'Crafting delightful customer experiences';

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: isEditing ? 320 : 260,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.pop(),
      ),
      actions: [
        if (!isEditing)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEditToggle,
          ),
      ],
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
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          AppAvatar(
                            imageUrl: tempAvatarUrl ?? user.avatarUrl,
                            initials:
                                user.displayName.isNotEmpty ? user.displayName[0] : '?',
                            size: 82,
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: isUploadingAvatar || isSaving ? null : onPickAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: isUploadingAvatar
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEditing)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: nameController,
                                  enabled: !isSaving,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                    hintText: 'Enter your name',
                                  ),
                                ),
                              )
                            else
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              user.phoneNumber,
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
                                  Flexible(
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving ? null : onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF4E5FF8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF4E5FF8),
                                      ),
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final baseColor = theme.brightness == Brightness.dark
        ? AppColors.surfaceDark
        : Colors.white;

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
              color: theme.brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade600,
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
    final baseColor = theme.brightness == Brightness.dark
        ? AppColors.surfaceDark
        : Colors.white;

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
              color: theme.brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade600,
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
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
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
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
                child: const Icon(Icons.headset_mic_outlined,
                    color: AppColors.primary),
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
          Column(
            children: [
              SizedBox(
                width: double.infinity,
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  onPressed: () {
                    onSignOut();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/security/secure_storage.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/sync_provider.dart';
import '../common_widgets/vault_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final theme     = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VaultAppBar(title: 'Settings', showBackButton: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Profile card ───────────────────────────────────────────────
          if (user != null)
            _ProfileCard(
              displayName: user.displayName,
              email: user.email,
              avatarUrl: user.profilePicUrl,
            ),

          const SizedBox(height: 24),

          // ── Security ───────────────────────────────────────────────────
          const _SectionLabel('Security'),
          const _SettingsTile(
            icon: Icons.fingerprint_rounded,
            label: 'Biometric Lock',
            subtitle: 'Require fingerprint or face to open vault',
            trailing: _BiometricToggle(),
          ),
          const SizedBox(height: 8),
          _PinManagementTile(),
          const SizedBox(height: 8),
          const _SettingsTile(
            icon: Icons.verified_user_rounded,
            label: 'Tamper Detection',
            subtitle: 'SHA-256 hash verification on every open',
            trailing: Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
          ),

          const SizedBox(height: 20),

          // ── Cloud sync ─────────────────────────────────────────────────
          const _SectionLabel('Cloud Backup'),
          _SettingsTile(
            icon: Icons.cloud_sync_rounded,
            label: 'Sync to Cloud',
            subtitle: pendingAsync.when(
              data: (n) => n == 0
                  ? 'All documents synced'
                  : '$n document${n == 1 ? '' : 's'} pending',
              loading: () => 'Checking…',
              error: (_, __) => 'Sync unavailable',
            ),
            trailing: syncState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.primary),
                    onPressed: () =>
                        ref.read(syncProvider.notifier).sync(),
                  ),
          ),
          if (syncState.lastSyncTime != null)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Text(
                'Last synced: ${_formatTime(syncState.lastSyncTime!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant),
              ),
            ),

          const SizedBox(height: 20),

          // ── Storage ────────────────────────────────────────────────────
          const _SectionLabel('Storage'),
          const _SettingsTile(
            icon: Icons.storage_rounded,
            label: 'Local Storage',
            subtitle: 'Documents stored on device (primary)',
            trailing: Icon(Icons.phone_android_rounded,
                color: AppColors.primary, size: 20),
          ),
          const _SettingsTile(
            icon: Icons.cloud_rounded,
            label: 'Cloud Backup',
            subtitle: 'Supabase encrypted backup',
            trailing: Icon(Icons.lock_rounded,
                color: AppColors.success, size: 20),
          ),

          const SizedBox(height: 20),

          // ── About ──────────────────────────────────────────────────────
          const _SectionLabel('About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            subtitle: 'DocsVault AI v1.0.0 — Google Solution Challenge 2026',
          ),
          _SettingsTile(
            icon: Icons.shield_rounded,
            label: 'Privacy Policy',
            subtitle: 'Your documents never leave your device without permission',
            onTap: () {},
          ),

          const SizedBox(height: 32),

          // ── Sign out ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String? avatarUrl;

  const _ProfileCard({
    required this.displayName,
    required this.email,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(email, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    )),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricToggle extends StatefulWidget {
  const _BiometricToggle();

  @override
  State<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends State<_BiometricToggle> {
  bool _enabled = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await SecureStorage.isBiometricLockEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _setBiometricLock(bool value) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      if (value) {
        var hasPin = await SecureStorage.getAppPin() != null;
        if (!hasPin) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Set an app PIN before enabling biometric lock.'),
            ),
          );
          await context.push(RouteNames.pinSetup);
          hasPin = await SecureStorage.getAppPin() != null;
          if (!hasPin) return;
        }

        final biometricsReady = await BiometricAuth.isAvailable();
        if (!biometricsReady) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Set up fingerprint or face in your device settings first.'),
            ),
          );
          return;
        }
      }

      final ok = await BiometricAuth.authenticate(
        reason: value
            ? 'Enable biometric lock for DocVault'
            : 'Disable biometric lock for DocVault',
      );
      if (!ok) return;

      await SecureStorage.setBiometricLockEnabled(value);
      if (mounted) {
        setState(() => _enabled = value);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Switch(
        value: _enabled,
        activeThumbColor: AppColors.primary,
        onChanged: _loading || _busy ? null : _setBiometricLock,
      );
}

class _PinManagementTile extends StatefulWidget {
  @override
  State<_PinManagementTile> createState() => _PinManagementTileState();
}

class _PinManagementTileState extends State<_PinManagementTile> {
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await SecureStorage.getAppPin();
    if (mounted) setState(() => _hasPin = pin != null);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.pin_outlined,
      label: _hasPin ? 'Change App PIN' : 'Set App PIN',
      subtitle: _hasPin
          ? 'Update your 4-digit unlock PIN'
          : 'Protect your vault with a 4-digit PIN',
      trailing: _hasPin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Remove PIN button
                GestureDetector(
                  onTap: () async {
                    await SecureStorage.deleteAppPin();
                    await SecureStorage.setBiometricLockEnabled(false);
                    if (!context.mounted) return;
                    setState(() => _hasPin = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN removed successfully')),
                    );
                  },
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant, size: 22),
              ],
            )
          : const Icon(Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant, size: 22),
      onTap: () async {
        await context.push(RouteNames.pinSetup);
        if (!context.mounted) return;
        // Reload after returning from pin setup
        _loadPin();
      },
    );
  }
}

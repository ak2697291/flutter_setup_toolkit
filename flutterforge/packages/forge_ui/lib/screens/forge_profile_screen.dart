import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_state/forge_state.dart';
import 'package:forge_ui/config/forge_ui_config.dart';

class ForgeProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onEditProfile;
  final VoidCallback? onUpgradeSubscription;
  final VoidCallback? onPrivacyPolicyTap;
  final VoidCallback? onTermsOfServiceTap;
  final VoidCallback? onSignOut;
  final List<Widget>? extraSettingsTiles;
  final String? premiumTierName; // Standard override if custom package manages billing
  final ForgeProfileConfig? config;
  
  const ForgeProfileScreen({
    super.key,
    this.onEditProfile,
    this.onUpgradeSubscription,
    this.onPrivacyPolicyTap,
    this.onTermsOfServiceTap,
    this.onSignOut,
    this.extraSettingsTiles,
    this.premiumTierName,
    this.config,
  });

  @override
  ConsumerState<ForgeProfileScreen> createState() => _ForgeProfileScreenState();
}

class _ForgeProfileScreenState extends ConsumerState<ForgeProfileScreen> {
  bool _isSigningOut = false;
  bool _darkModeEnabled = false;
  bool _pushNotificationsEnabled = true;

  ForgeProfileConfig _resolveConfig() {
    if (widget.config != null) return widget.config!;
    try {
      if (GetIt.instance.isRegistered<ForgeUIConfig>()) {
        return GetIt.instance<ForgeUIConfig>().profile;
      }
    } catch (_) {}
    return const ForgeProfileConfig();
  }

  @override
  void initState() {
    super.initState();
    Analytics.track('forge_profile_screen_viewed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleSignOut() async {
    // Show premium confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSigningOut = true);
    Analytics.track('profile_sign_out_initiated', {});

    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.signOut();

      Analytics.track('profile_sign_out_success', {});
      if (widget.onSignOut != null) {
        widget.onSignOut!();
      }
    } catch (e) {
      Analytics.track('profile_sign_out_failed', {
        'error': e.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    final user = ref.watch(currentUserProvider);
    final userEmail = user?.email ?? 'developer@flutterforge.com';
    final userDisplayName = user?.displayName ?? 'Forge Developer';
    final photoUrl = user?.photoUrl;
    
    // Premium badge custom gradients based on tier
    final tier = widget.premiumTierName ?? _resolveConfig().premiumTierName ?? 'Pro Developer';
    final tierGradients = {
      'Starter': [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
      'Pro': [const Color(0xFFF953C6), const Color(0xFFB91D73)],
      'Enterprise': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    };
    final activeGradient = tierGradients[tier] ?? [colors.primary, colors.secondary];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          _resolveConfig().title ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_resolveConfig().allowEditProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEditProfile ?? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile is not configured.')),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Premium sophisticated background gradients
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.surface,
                    // ignore: deprecated_member_use
                    colors.surfaceVariant.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          Positioned(
            top: -100,
            right: -80,
            child: CircleAvatar(
              radius: 180,
              backgroundColor: colors.primary.withValues(alpha: 0.05),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  
                  // Header section: User Avatar & Basic Info
                  Center(
                    child: Column(
                      children: [
                        // Avatar overlay design
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: activeGradient),
                              ),
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: colors.surface,
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null
                                    ? Text(
                                        userDisplayName.isNotEmpty ? userDisplayName[0].toUpperCase() : 'F',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.surface, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          userDisplayName,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Active subscription badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: activeGradient),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: activeGradient.first.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tier.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section Title: Subscription Info Card
                  _buildSectionHeader('Subscription & Billing'),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Plan',
                                    style: textTheme.bodySmall?.copyWith(color: colors.outline),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tier,
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (widget.premiumTierName == null || widget.premiumTierName == 'Starter')
                                ElevatedButton(
                                  onPressed: widget.onUpgradeSubscription ?? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Subscription upgrades are not configured.')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Upgrade'),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Auto-renewing',
                                    style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_resolveConfig().showBillingHistory) ...[
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildProfileListTile(
                              icon: Icons.receipt_long_outlined,
                              iconColor: Colors.purple,
                              title: 'Billing History',
                              subtitle: 'View and download past invoices',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invoices functionality is coming soon!')),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Title: Preferences
                  if (_resolveConfig().showPreferences) ...[
                    _buildSectionHeader('Preferences'),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            SwitchListTile(
                              secondary: _buildIconBackground(Icons.dark_mode_outlined, Colors.indigo),
                              title: const Text('Dark Mode'),
                              subtitle: const Text('Toggle between dark and light themes'),
                              value: _darkModeEnabled,
                              onChanged: (val) {
                                setState(() => _darkModeEnabled = val);
                                Analytics.track('profile_pref_changed', {
                                  'preference': 'dark_mode',
                                  'value': val,
                                });
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: _buildIconBackground(Icons.notifications_active_outlined, Colors.amber.shade700),
                              title: const Text('Push Notifications'),
                              subtitle: const Text('Stay updated with real-time analytics alerts'),
                              value: _pushNotificationsEnabled,
                              onChanged: (val) {
                                setState(() => _pushNotificationsEnabled = val);
                                Analytics.track('profile_pref_changed', {
                                  'preference': 'push_notifications',
                                  'value': val,
                                });
                              },
                            ),
                            const Divider(height: 1),
                            _buildProfileListTile(
                              icon: Icons.language_outlined,
                              iconColor: Colors.blue,
                              title: 'Language',
                              subtitle: 'English (US)',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Language settings coming soon.')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Extra Custom Settings Tiles
                  if (widget.extraSettingsTiles != null && widget.extraSettingsTiles!.isNotEmpty) ...[
                    _buildSectionHeader('More Settings'),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: widget.extraSettingsTiles!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Section Title: Support & Security
                  _buildSectionHeader('Support & Legal'),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          if (_resolveConfig().showSupport) ...[
                            _buildProfileListTile(
                              icon: Icons.help_outline_rounded,
                              iconColor: Colors.teal,
                              title: 'Help Center',
                              subtitle: 'Read documentation & FAQs',
                              onTap: () {
                                final url = _resolveConfig().helpCenterUrl;
                                if (url != null && url.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Redirecting to Help Center: $url')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Redirecting to FlutterForge documentation...')),
                                  );
                                }
                              },
                            ),
                            const Divider(height: 1),
                          ],
                          _buildProfileListTile(
                            icon: Icons.shield_outlined,
                            iconColor: Colors.blueGrey,
                            title: 'Privacy Policy',
                            subtitle: 'Review how we protect your data',
                            onTap: widget.onPrivacyPolicyTap ?? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Privacy Policy not loaded.')),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildProfileListTile(
                            icon: Icons.description_outlined,
                            iconColor: Colors.orange,
                            title: 'Terms of Service',
                            subtitle: 'Read terms of application usage',
                            onTap: widget.onTermsOfServiceTap ?? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Terms of Service not loaded.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout Button
                  if (_resolveConfig().allowLogout) ...[
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isSigningOut ? null : _handleSignOut,
                        icon: _isSigningOut
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                              )
                            : const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.02),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ] else
                    const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIconBackground(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildProfileListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: _buildIconBackground(icon, iconColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

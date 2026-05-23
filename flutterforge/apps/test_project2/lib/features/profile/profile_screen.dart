import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_state/forge_state.dart' hide sl;
import 'package:forge_backend/forge_backend.dart';
import 'package:forge_analytics/forge_analytics.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return ForgeProfileScreen(
      onSignOut: () {
        context.go('/login');
      },
      onUpgradeSubscription: () {
        context.push('/subscription');
      },
      extraSettingsTiles: [
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('Simulate Role Change'),
          subtitle: Text("Current Role: ${user?.role.value ?? 'Unknown'}"),
          trailing: const Icon(Icons.swap_horiz_rounded),
          onTap: () async {
            final backend = sl<BackendService>();
            final oldRole = user?.role.value ?? 'Unknown';
            final newRole = user?.role == ForgeRole.admin 
                ? ForgeRole.user 
                : ForgeRole.admin;
            
            final result = await backend.updateCurrentUser(
              metadata: {'role': newRole.value},
            );
            
            if (context.mounted) {
              result.fold(
                (failure) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to update role: ${failure.message}")),
                ),
                (updatedUser) {
                  Analytics.track('role_changed', {
                    'old_role': oldRole,
                    'new_role': updatedUser.role.value,
                    'user_id': updatedUser.id,
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Role updated to: ${updatedUser.role.value}")),
                  );
                },
              );
            }
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ForgeProfileScreen(
      onSignOut: () {
        context.go('/login');
      },
      onUpgradeSubscription: () {
        context.push('/subscription');
      },
    );
  }
}

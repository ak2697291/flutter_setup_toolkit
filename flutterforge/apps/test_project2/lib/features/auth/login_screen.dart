import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ForgeLoginScreen(
      onAuthSuccess: (_) {
        context.go('/');
      },
      onAuthFailure: (error) {
        // Handle failure if needed, although ForgeLoginScreen already displays standard dialog/snackbar.
      },
    );
  }
}
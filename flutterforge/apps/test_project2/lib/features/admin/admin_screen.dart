import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_state/forge_state.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Log admin screen viewed
    Analytics.track('admin_screen_viewed', {
      'user_id': user?.id,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management'),
        backgroundColor: Colors.redAccent,
      ),
      body: const Center(
        child: Text('Welcome to the Secret Admin Panel!'),
      ),
    );
  }
}

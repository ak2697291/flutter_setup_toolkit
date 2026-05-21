import 'package:flutter/material.dart';
import 'forge_role.dart';

/// A widget that conditionally shows its [child] based on the [currentRole].
///
/// If [currentRole] is in [allowedRoles], [child] is displayed.
/// Otherwise, [fallback] (or an empty box) is displayed.
class RBACGate extends StatelessWidget {
  final ForgeRole? currentRole;
  final List<ForgeRole> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RBACGate({
    super.key,
    required this.currentRole,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = currentRole != null && allowedRoles.contains(currentRole);

    if (hasAccess) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

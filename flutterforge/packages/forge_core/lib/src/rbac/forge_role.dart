/// Represents a user role in the FlutterForge ecosystem.
/// Use strings for flexibility, allowing apps to define custom roles.
class ForgeRole {
  final String value;

  const ForgeRole(this.value);

  static const admin = ForgeRole('admin');
  static const user = ForgeRole('user');
  static const guest = ForgeRole('guest');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgeRole &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ForgeRole($value)';
}

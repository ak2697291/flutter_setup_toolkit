import 'package:dartz/dartz.dart';
import 'package:forge_core/forge_core.dart';

/// The unified backend interface. Both Supabase and Firebase implementations
/// conform to this contract — swap providers by changing forge.yaml.
abstract class BackendService {
  // ─── Auth ───────────────────────────────────────────────────────
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithEmail({required String email, required String password});
  Future<Either<ForgeFailure, AuthUserDetails>> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? contactNumber,
  });
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithGoogle();
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithApple();
  Future<Either<ForgeFailure, Unit>> signOut();
  Stream<AuthUserDetails?> get authStateChanges;
  AuthUserDetails? get currentUser;

  // ─── Database ───────────────────────────────────────────────────
  Future<Either<ForgeFailure, Map<String, dynamic>>> getDocument({required String collection, required String id});
  Future<Either<ForgeFailure, List<Map<String, dynamic>>>> getCollection({required String collection, Map<String, dynamic>? filters});
  Future<Either<ForgeFailure, String>> createDocument({required String collection, required Map<String, dynamic> data});
  Future<Either<ForgeFailure, Unit>> updateDocument({required String collection, required String id, required Map<String, dynamic> data});
  Future<Either<ForgeFailure, Unit>> deleteDocument({required String collection, required String id});
  Stream<List<Map<String, dynamic>>> watchCollection({required String collection, Map<String, dynamic>? filters});

  // ─── Storage ────────────────────────────────────────────────────
  Future<Either<ForgeFailure, String>> uploadFile({required String path, required List<int> bytes, String? contentType});
  Future<Either<ForgeFailure, Unit>> deleteFile({required String path});
  String getPublicUrl({required String path});
}

class AuthUserDetails {
  final String id;
  final String? email;
  final String? displayName;
  final String? contactNumber;
  final String? photoUrl;
  final bool emailVerified;
  const AuthUserDetails({
    required this.id,
    this.email,
    this.displayName,
    this.contactNumber,
    this.photoUrl,
    this.emailVerified = false,
  });
}

import 'package:dartz/dartz.dart';
import 'package:forge_core/forge_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../interface/backend_service.dart';
import 'dart:typed_data';

class SupabaseBackend implements BackendService {
  final SupabaseClient _client;
  SupabaseBackend(this._client);

  static Future<SupabaseBackend> init({required String url, required String anonKey}) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
    return SupabaseBackend(Supabase.instance.client);
  }

  // ─── Auth ──────────────────────────────────────────────────────
  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithEmail({required String email, required String password}) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? contactNumber,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (name != null) 'full_name': name,
          if (contactNumber != null) 'contact_number': contactNumber,
        },
      );
      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      final user = _client.auth.currentUser;
      if (user == null) return Left(const AuthFailure(message: 'Google sign-in failed'));
      return Right(_mapUser(user));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.apple);
      final user = _client.auth.currentUser;
      if (user == null) return Left(const AuthFailure(message: 'Apple sign-in failed'));
      return Right(_mapUser(user));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, Unit>> signOut() async {
    try { await _client.auth.signOut(); return const Right(unit); }
    catch (e) { return Left(UnknownFailure(message: e.toString())); }
  }

  @override
  Stream<AuthUserDetails?> get authStateChanges => _client.auth.onAuthStateChange
      .map((event) => event.session?.user != null ? _mapUser(event.session!.user) : null);

  @override
  AuthUserDetails? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  // ─── Database ─────────────────────────────────────────────────
  @override
  Future<Either<ForgeFailure, Map<String, dynamic>>> getDocument({required String collection, required String id}) async {
    try {
      final data = await _client.from(collection).select().eq('id', id).single();
      return Right(data);
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<ForgeFailure, List<Map<String, dynamic>>>> getCollection({required String collection, Map<String, dynamic>? filters}) async {
    try {
      var query = _client.from(collection).select();
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      final data = await query;
      return Right(List<Map<String, dynamic>>.from(data));
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<ForgeFailure, String>> createDocument({required String collection, required Map<String, dynamic> data}) async {
    try {
      final result = await _client.from(collection).insert(data).select().single();
      return Right(result['id'].toString());
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<ForgeFailure, Unit>> updateDocument({required String collection, required String id, required Map<String, dynamic> data}) async {
    try {
      await _client.from(collection).update(data).eq('id', id);
      return const Right(unit);
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<ForgeFailure, Unit>> deleteDocument({required String collection, required String id}) async {
    try {
      await _client.from(collection).delete().eq('id', id);
      return const Right(unit);
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCollection({required String collection, Map<String, dynamic>? filters}) {
    return _client.from(collection).stream(primaryKey: ['id'])
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ─── Storage ──────────────────────────────────────────────────
  @override
  Future<Either<ForgeFailure, String>> uploadFile({required String path, required List<int> bytes, String? contentType}) async {
    try {
      final parts = path.split('/');
      final bucket = parts.first;
      final filePath = parts.skip(1).join('/');
      await _client.storage.from(bucket).uploadBinary(filePath, bytes as Uint8List);
      return Right(getPublicUrl(path: path));
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<ForgeFailure, Unit>> deleteFile({required String path}) async {
    try {
      final parts = path.split('/');
      await _client.storage.from(parts.first).remove([parts.skip(1).join('/')]);
      return const Right(unit);
    } catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  String getPublicUrl({required String path}) {
    final parts = path.split('/');
    return _client.storage.from(parts.first).getPublicUrl(parts.skip(1).join('/'));
  }

  AuthUserDetails _mapUser(User user) => AuthUserDetails(
    id: user.id, email: user.email,
    displayName: user.userMetadata?['full_name'] as String?,
    contactNumber: user.userMetadata?['contact_number'] as String?,
    photoUrl: user.userMetadata?['avatar_url'] as String?,
    emailVerified: user.emailConfirmedAt != null,
  );
}



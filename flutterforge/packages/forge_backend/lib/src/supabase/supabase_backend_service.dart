import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:forge_core/forge_core.dart';
import '../interface/backend_service.dart' show BackendService, AuthUserDetails;

class SupabaseBackendService implements BackendService {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  // Default bucket for all storage operations
  final String _storageBucket;

  SupabaseBackendService({
    required SupabaseClient client,
    GoogleSignIn? googleSignIn,
    String storageBucket = 'public',
  })  : _client = client,
        _storageBucket = storageBucket,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  // ─── Auth ─────────────────────────────────────────────────────────────────

  @override
  AuthUserDetails? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AuthUserDetails?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) {
        final user = event.session?.user;
        return user == null ? null : _mapUser(user);
      });

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
          if (name != null) 'display_name': name,
          if (contactNumber != null) 'contact_number': contactNumber,
          'role': ForgeRole.user.value,
        },
      );
      if (res.user == null) {
        return Left(ForgeFailure.auth('Sign up failed — check your email for confirmation'));
      }
      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(ForgeFailure.auth(e.message, code: e.statusCode));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) {
        return Left(ForgeFailure.auth('Sign in failed — invalid credentials'));
      }
      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(ForgeFailure.auth(e.message, code: e.statusCode));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        return Left(ForgeFailure.auth('Google sign-in failed — missing ID token'));
      }

      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.idToken!, // FIX: Supabase uses idToken for both fields in this case
      );

      if (res.user == null) {
        return Left(ForgeFailure.auth('Google sign-in failed — no user returned'));
      }

      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(ForgeFailure.auth(e.message));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'your.app.scheme://auth/callback',
      );

      final user = await _client.auth.onAuthStateChange
          .where((event) =>
              event.event == AuthChangeEvent.signedIn &&
              event.session?.user != null)
          .map((event) => event.session!.user)
          .first
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw AuthException('Apple sign-in timed out'),
          );

      return Right(_mapUser(user));
    } on AuthException catch (e) {
      return Left(ForgeFailure.auth(e.message));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, AuthUserDetails>> updateCurrentUser({
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final res = await _client.auth.updateUser(
        UserAttributes(
          data: metadata,
        ),
      );
      if (res.user == null) {
        return Left(ForgeFailure.auth('Update user failed'));
      }
      return Right(_mapUser(res.user!));
    } on AuthException catch (e) {
      return Left(ForgeFailure.auth(e.message, code: e.statusCode));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, Unit>> signOut() async {
  try {
    // Google Sign Out
    await _googleSignIn.signOut();

    // Supabase Sign Out
    await _client.auth.signOut();

    return const Right(unit);
  } on AuthException catch (e) {
    return Left(ForgeFailure.auth(e.message));
  } catch (e) {
    return Left(ForgeFailure.unknown(e.toString()));
  }
}

  // ─── Database ─────────────────────────────────────────────────────────────

  @override
  Future<Either<ForgeFailure, Map<String, dynamic>>> getDocument({
    required String collection,
    required String id,
  }) async {
    try {
      final res = await _client
          .from(collection)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) {
        return Left(ForgeFailure.database('Document not found'));
      }
      return Right(res);
    } on PostgrestException catch (e) {
      return Left(ForgeFailure.database(e.message, code: e.code));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, List<Map<String, dynamic>>>> getCollection({
    required String collection,
    Map<String, dynamic>? filters,
  }) async {
    try {
      dynamic query = _client.from(collection).select();
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      final res = await query;
      return Right((res as List).cast<Map<String, dynamic>>());
    } on PostgrestException catch (e) {
      return Left(ForgeFailure.database(e.message, code: e.code));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, String>> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      final res = await _client
          .from(collection)
          .insert(data)
          .select('id')
          .single();
      return Right(res['id'] as String); // FIX: returns id as String
    } on PostgrestException catch (e) {
      return Left(ForgeFailure.database(e.message, code: e.code));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, Unit>> updateDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _client.from(collection).update(data).eq('id', id);
      return const Right(unit); // FIX: Unit not void
    } on PostgrestException catch (e) {
      return Left(ForgeFailure.database(e.message, code: e.code));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, Unit>> deleteDocument({
    required String collection,
    required String id,
  }) async {
    try {
      await _client.from(collection).delete().eq('id', id);
      return const Right(unit); // FIX: Unit not void
    } on PostgrestException catch (e) {
      return Left(ForgeFailure.database(e.message, code: e.code));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

@override
Stream<List<Map<String, dynamic>>> watchCollection({
  required String collection,
  Map<String, dynamic>? filters,
}) {
  final stream = _client.from(collection).stream(primaryKey: ['id']);

  if (filters == null || filters.isEmpty) {
    return stream;
  }

  return stream.map((rows) {
    return rows.where((row) {
      for (final entry in filters.entries) {
        if (row[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }).toList();
  });
}

  // ─── Storage ──────────────────────────────────────────────────────────────

  @override
  Future<Either<ForgeFailure, String>> uploadFile({
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    try {
      // FIX: bucket sourced from constructor, not method param
      await _client.storage.from(_storageBucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType),
          );
      final url = _client.storage.from(_storageBucket).getPublicUrl(path);
      return Right(url);
    } on StorageException catch (e) {
      return Left(ForgeFailure.storage(e.message));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<ForgeFailure, Unit>> deleteFile({required String path}) async {
    try {
      // FIX: bucket sourced from constructor, not method param
      await _client.storage.from(_storageBucket).remove([path]);
      return const Right(unit);
    } on StorageException catch (e) {
      return Left(ForgeFailure.storage(e.message));
    } catch (e) {
      return Left(ForgeFailure.unknown(e.toString()));
    }
  }

  @override
  String getPublicUrl({required String path}) {
    // FIX: sync method as per interface — no Either, no async
    return _client.storage.from(_storageBucket).getPublicUrl(path);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  AuthUserDetails _mapUser(User user) => AuthUserDetails(
        id: user.id,
        email: user.email,
        displayName: user.userMetadata?['display_name'] as String?,
        contactNumber: user.userMetadata?['contact_number'] as String?,
        photoUrl: user.userMetadata?['avatar_url'] as String?, // FIX: was avatarUrl
        emailVerified: user.emailConfirmedAt != null,           // FIX: was missing
        role: ForgeRole(user.userMetadata?['role'] as String? ?? ForgeRole.user.value),
      );
}

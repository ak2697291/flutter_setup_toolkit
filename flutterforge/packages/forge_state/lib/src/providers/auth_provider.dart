import 'package:forge_backend/forge_backend.dart';
import 'package:forge_core/forge_core.dart';


final sl = GetIt.instance;

/// Auth state for the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AuthUserDetails user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

/// Riverpod provider for authentication state.
///
/// In your widget:
/// ```dart
/// final authState = ref.watch(authStateProvider);
/// switch (authState) {
///   case AuthAuthenticated(:final user) => HomeScreen(user: user),
///   case AuthUnauthenticated() => LoginScreen(),
///   ...
/// }
/// ```
class AuthNotifier extends AsyncNotifier<AuthState> {
  late BackendService _backend;

  @override
  Future<AuthState> build() async {
    _backend = sl<BackendService>();

    // Listen to auth state changes
    _backend.authStateChanges.listen((user) {
      state = AsyncData(
        user != null
            ? AuthAuthenticated(user)
            : const AuthUnauthenticated(),
      );
    });

    // Return current state
    final currentUser = _backend.currentUser;
    return currentUser != null
        ? AuthAuthenticated(currentUser)
        : const AuthUnauthenticated();
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncData(AuthLoading());
    final result = await _backend.signInWithEmail(
      email: email,
      password: password,
    );
    result.fold(
      (failure) => state = AsyncData(AuthError(failure.message)),
      (user) => state = AsyncData(AuthAuthenticated(user)),
    );
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? name,
    String? contactNumber,
  }) async {
    state = const AsyncData(AuthLoading());
    final result = await _backend.signUpWithEmail(
      email: email,
      password: password,
      name: name,
      contactNumber: contactNumber,
    );
    result.fold(
      (failure) => state = AsyncData(AuthError(failure.message)),
      (user) => state = AsyncData(AuthAuthenticated(user)),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncData(AuthLoading());
    final result = await _backend.signInWithGoogle();
    result.fold(
      (failure) => state = AsyncData(AuthError(failure.message)),
      (user) => state = AsyncData(AuthAuthenticated(user)),
    );
  }

  Future<void> signOut() async {
    await _backend.signOut();
    state = const AsyncData(AuthUnauthenticated());
  }
}

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Convenience provider that returns the current user or null.
final currentUserProvider = Provider<AuthUserDetails?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState is AuthAuthenticated ? authState.user : null;
});

/// True if user is logged in.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

import 'package:equatable/equatable.dart';

abstract class ForgeFailure extends Equatable {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const ForgeFailure({required this.message, this.code, this.stackTrace});

  // ─── Factories ────────────────────────────────────────────────────────────

  factory ForgeFailure.auth(String message, {String? code}) =>
      AuthFailure(message: message, code: code);

  factory ForgeFailure.database(String message, {String? code}) =>
      ServerFailure(message: message, code: code);

  factory ForgeFailure.storage(String message, {String? code}) =>
      ServerFailure(message: message, code: code);

  factory ForgeFailure.network(String message, {String? code}) =>
      NetworkFailure(message: message, code: code);

  factory ForgeFailure.cache(String message) =>
      CacheFailure(message: message);

  factory ForgeFailure.unknown(String message, {StackTrace? stackTrace}) =>
      UnknownFailure(message: message, stackTrace: stackTrace);

  factory ForgeFailure.payment(String message, {String? code}) =>
      ServerFailure(message: message, code: code);

  factory ForgeFailure.server(String message, {String? code}) =>
      ServerFailure(message: message, code: code);

  @override
  List<Object?> get props => [message, code];
}

// ─── Subclasses ───────────────────────────────────────────────────────────────

class NetworkFailure extends ForgeFailure {
  const NetworkFailure({required super.message, super.code});
}

class AuthFailure extends ForgeFailure {
  const AuthFailure({required super.message, super.code});
}

class ServerFailure extends ForgeFailure {
  const ServerFailure({required super.message, super.code});
}

class CacheFailure extends ForgeFailure {
  const CacheFailure({required super.message});
}

class UnknownFailure extends ForgeFailure {
  const UnknownFailure({required super.message, super.stackTrace});
}
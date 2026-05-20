#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:args/command_runner.dart';
import '../lib/src/commands/create_command.dart';
import '../lib/src/commands/generate_command.dart';
import '../lib/src/commands/doctor_command.dart';

/// FlutterForge CLI — forge <command> [arguments]
///
/// Install globally:
///   dart pub global activate --source path .
///
/// Then use anywhere:
///   forge create my_app
///   forge generate
///   forge doctor

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'forge',
    '⚡ FlutterForge — Flutter starter framework generator',
  )
    ..addCommand(CreateCommand())
    ..addCommand(GenerateCommand())
    ..addCommand(DoctorCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print('\n❌ ${e.message}\n');
    print(e.usage);
    exit(64);
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

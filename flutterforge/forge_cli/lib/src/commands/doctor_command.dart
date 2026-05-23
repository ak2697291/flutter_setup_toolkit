import 'dart:io';
import 'package:args/command_runner.dart';
import '../config/forge_config.dart';

class DoctorCommand extends Command<void> {
  @override
  String get name => 'doctor';

  @override
  String get description => 'Check your FlutterForge setup for issues';

  @override
  Future<void> run() async {
    print('\n⚡ FlutterForge Doctor\n');
    print('Checking your environment...\n');

    final checks = <_Check>[];

    // Flutter SDK
    final flutterVersion = await _runCheck('flutter', ['--version']);
    checks.add(_Check(
      name: 'Flutter SDK',
      passed: flutterVersion.exitCode == 0,
      detail: flutterVersion.exitCode == 0
          ? flutterVersion.stdout.toString().split('\n').first
          : 'flutter not found in PATH — install from flutter.dev',
    ));

    // Dart SDK
    final dartVersion = await _runCheck('dart', ['--version']);
    checks.add(_Check(
      name: 'Dart SDK',
      passed: dartVersion.exitCode == 0,
      detail: dartVersion.exitCode == 0
          ? dartVersion.stdout.toString().trim()
          : 'dart not found',
    ));

    // Melos
    final melosVersion = await _runCheck('melos', ['--version']);
    checks.add(_Check(
      name: 'Melos (monorepo)',
      passed: melosVersion.exitCode == 0,
      detail: melosVersion.exitCode == 0
          ? 'melos ${melosVersion.stdout.toString().trim()}'
          : 'Not installed — run: dart pub global activate melos',
    ));

    // forge.yaml
    final forgeYamlFile = File('forge.yaml');
    final forgeYamlExists = forgeYamlFile.existsSync();
    String forgeYamlDetail = 'Not found — run forge create <app_name> or create forge.yaml manually';
    bool forgeYamlPassed = forgeYamlExists;

    if (forgeYamlExists) {
      try {
        final config = ForgeConfig.load();
        final errors = config.validate();
        if (errors.isEmpty) {
          forgeYamlDetail = 'Found and valid ✅';
          if (config.app.developerName == null || config.app.contactNumber == null) {
            forgeYamlDetail += ' (Warning: developer_name or contact_number missing)';
          }
        } else {
          forgeYamlDetail = 'Found but has errors: ${errors.first}';
          forgeYamlPassed = false;
        }
      } catch (e) {
        forgeYamlDetail = 'Error parsing forge.yaml: $e';
        forgeYamlPassed = false;
      }
    }

    checks.add(_Check(
      name: 'forge.yaml',
      passed: forgeYamlPassed,
      detail: forgeYamlDetail,
    ));

    // .env files
    final devEnv = File('.env.dev.json');
    checks.add(_Check(
      name: '.env.dev.json',
      passed: devEnv.existsSync(),
      detail: devEnv.existsSync()
          ? 'Found ✅ (remember to fill in real credentials)'
          : 'Missing — run: forge create or copy from .env.dev.json.example',
    ));

    // Android toolchain
    final adb = await _runCheck('adb', ['version']);
    checks.add(_Check(
      name: 'Android toolchain',
      passed: adb.exitCode == 0,
      detail: adb.exitCode == 0
          ? 'ADB available'
          : 'ADB not found — install Android Studio + SDK',
    ));

    // Xcode (macOS only)
    if (Platform.isMacOS) {
      final xcode = await _runCheck('xcode-select', ['--version']);
      checks.add(_Check(
        name: 'Xcode (iOS/macOS)',
        passed: xcode.exitCode == 0,
        detail: xcode.exitCode == 0
            ? xcode.stdout.toString().trim()
            : 'Xcode not found — install from App Store',
      ));

      final pod = await _runCheck('pod', ['--version']);
      checks.add(_Check(
        name: 'CocoaPods',
        passed: pod.exitCode == 0,
        detail: pod.exitCode == 0
            ? 'pod ${pod.stdout.toString().trim()}'
            : 'Not installed — run: sudo gem install cocoapods',
      ));
    }

    // Print results
    int passed = 0;
    int failed = 0;

    for (final check in checks) {
      final icon = check.passed ? '✅' : '❌';
      print('$icon ${check.name.padRight(25)} ${check.detail}');
      if (check.passed) passed++; else failed++;
    }

    print('\n─────────────────────────────────────────');
    print('$passed passed · $failed failed');

    if (failed == 0) {
      print('\n🎉 All checks passed! You\'re ready to forge.\n');
    } else {
      print('\n⚠️  Fix the issues above, then run forge doctor again.\n');
      exit(1);
    }
  }

  Future<ProcessResult> _runCheck(String cmd, List<String> args) async {
    try {
      return await Process.run(cmd, args, runInShell: true);
    } catch (_) {
      return ProcessResult(0, 1, '', 'command not found');
    }
  }
}

class _Check {
  final String name;
  final bool passed;
  final String detail;
  const _Check({required this.name, required this.passed, required this.detail});
}

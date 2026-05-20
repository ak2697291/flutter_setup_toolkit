import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

class CreateCommand extends Command<void> {
  @override
  String get name => 'create';

  @override
  String get description => 'Create a new FlutterForge project';

  CreateCommand() {
    argParser
      ..addOption('preset',
          abbr: 'p',
          help: 'Project preset to use',
          allowed: ['saas', 'marketplace', 'ecommerce', 'blank'],
          defaultsTo: 'blank')
      ..addOption('backend',
          abbr: 'b',
          help: 'Backend provider',
          allowed: ['supabase', 'firebase'],
          defaultsTo: 'supabase')
      ..addFlag('payments',
          help: 'Include forge_payments', defaultsTo: false)
      ..addFlag('analytics',
          help: 'Include forge_analytics', defaultsTo: true)
      ..addFlag('no-git',
          help: 'Skip git initialization', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Please provide a project name.\nUsage: forge create <app_name>');
    }

    final appName = rest.first;
    final preset = argResults!['preset'] as String;
    final backend = argResults!['backend'] as String;
    final includePayments = argResults!['payments'] as bool;
    final includeAnalytics = argResults!['analytics'] as bool;
    final skipGit = argResults!['no-git'] as bool;

    print('\n⚡ FlutterForge — Creating "$appName" ($preset preset)\n');

    // 1. Run flutter create
    print('📦 Running flutter create...');
    final flutterCreate = await Process.run(
      'flutter',
      ['create', '--org', 'com.example', '--project-name', appName, appName],
      runInShell: true,
    );

    if (flutterCreate.exitCode != 0) {
      print('❌ flutter create failed:\n${flutterCreate.stderr}');
      exit(1);
    }

    final projectDir = Directory(p.join(Directory.current.path, appName));

    // 2. Write forge.yaml
    print('📝 Writing forge.yaml...');
    _writeForgeYaml(projectDir.path, appName, backend,
        includePayments: includePayments,
        includeAnalytics: includeAnalytics);

    // 3. Write .env files
    print('🔐 Writing .env template files...');
    _writeEnvFiles(projectDir.path, backend);

    // 4. Write .gitignore additions
    _updateGitignore(projectDir.path);

    // 5. Git init
    if (!skipGit) {
      print('🔧 Initializing git...');
      await Process.run('git', ['init'], workingDirectory: projectDir.path);
      await Process.run('git', ['add', '.'], workingDirectory: projectDir.path);
      await Process.run(
          'git', ['commit', '-m', 'Initial FlutterForge scaffold'],
          workingDirectory: projectDir.path);
    }

    print('''
✅ Done! Your FlutterForge project is ready.

Next steps:
  cd $appName
  
  # Fill in your credentials:
  nano .env.dev.json

  # Run the app:
  flutter run --dart-define-from-file=.env.dev.json

  # Or use the forge CLI:
  forge generate    # Regenerates DI and routing from forge.yaml
  forge doctor      # Checks your setup

📖 Full setup guide: See SETUP.md in your project root.
''');
  }

  void _writeForgeYaml(
    String dir,
    String appName,
    String backend, {
    required bool includePayments,
    required bool includeAnalytics,
  }) {
    final bundleId = 'com.example.${appName.replaceAll('_', '')}';
    final content = StringBuffer('''
app:
  name: ${_toTitleCase(appName)}
  bundle_id: $bundleId
  platforms: [ios, android, web]
  primary_color: '#6200EA'

backend:
  provider: $backend
''');

    if (backend == 'supabase') {
      content.writeln('''  supabase:
    url: \$SUPABASE_URL
    anon_key: \$SUPABASE_ANON_KEY
''');
    } else {
      content.writeln('''  firebase:
    # Run: flutterfire configure
    # Then uncomment the generated firebase_options.dart import in main.dart
''');
    }

    if (includePayments) {
      content.writeln('''payments:
  providers: [razorpay, stripe]
  currency: INR
  razorpay:
    key_id: \$RAZORPAY_KEY_ID
  stripe:
    publishable_key: \$STRIPE_KEY
''');
    }

    if (includeAnalytics) {
      content.writeln('''analytics:
  providers: [posthog, firebase]
  posthog:
    api_key: \$POSTHOG_API_KEY
''');
    }

    content.writeln('''state:
  manager: riverpod
  local_db: isar
''');

    File(p.join(dir, 'forge.yaml')).writeAsStringSync(content.toString());
  }

  void _writeEnvFiles(String dir, String backend) {
    final devEnv = <String, String>{
      'FORGE_ENV': 'dev',
    };

    if (backend == 'supabase') {
      devEnv['SUPABASE_URL'] = 'https://YOUR_PROJECT_ID.supabase.co';
      devEnv['SUPABASE_ANON_KEY'] = 'YOUR_SUPABASE_ANON_KEY';
    }

    devEnv['RAZORPAY_KEY_ID'] = 'rzp_test_YOUR_KEY_ID';
    devEnv['STRIPE_KEY'] = 'pk_test_YOUR_STRIPE_KEY';
    devEnv['POSTHOG_API_KEY'] = 'YOUR_POSTHOG_API_KEY';
    devEnv['SENTRY_DSN'] = 'YOUR_SENTRY_DSN';

    final jsonContent = '{\n' +
        devEnv.entries
            .map((e) => '  "${e.key}": "${e.value}"')
            .join(',\n') +
        '\n}';

    File(p.join(dir, '.env.dev.json')).writeAsStringSync(jsonContent);

    // Prod env (empty template)
    final prodEnv = Map<String, String>.fromEntries(
      devEnv.entries.map((e) => MapEntry(e.key, '')),
    )..['FORGE_ENV'] = 'prod';

    final prodJson = '{\n' +
        prodEnv.entries
            .map((e) => '  "${e.key}": "${e.value}"')
            .join(',\n') +
        '\n}';
    File(p.join(dir, '.env.prod.json')).writeAsStringSync(prodJson);
  }

  void _updateGitignore(String dir) {
    final gitignore = File(p.join(dir, '.gitignore'));
    final existing = gitignore.existsSync() ? gitignore.readAsStringSync() : '';
    if (!existing.contains('.env.')) {
      gitignore.writeAsStringSync('''$existing

# FlutterForge env files (never commit these)
.env.*.json
.env.local.json
''');
    }
  }

  String _toTitleCase(String s) =>
      s.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

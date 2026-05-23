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
      ..addOption('developer-name',
          help: 'Developer name for the project')
      ..addOption('contact',
          help: 'Contact number for the project')
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
    final developerName = argResults!['developer-name'] as String?;
    final contactNumber = argResults!['contact'] as String?;
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
        includeAnalytics: includeAnalytics,
        developerName: developerName,
        contactNumber: contactNumber);

    // 3. Write .env files
    print('🔐 Writing .env template files...');
    _writeEnvFiles(projectDir.path, backend);

    // 3.5. Write assets/ui_config.yaml
    print('🎨 Writing assets/ui_config.yaml...');
    _writeUiConfigYaml(projectDir.path, appName);

    // 3.6. Update pubspec.yaml assets section
    print('📦 Updating pubspec.yaml assets...');
    _updatePubspecAssets(projectDir.path);

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

  # Customize your UI:
  nano assets/ui_config.yaml

📖 Full setup guide: See SETUP.md in your project root.
''');
  }

  void _writeForgeYaml(
    String dir,
    String appName,
    String backend, {
    required bool includePayments,
    required bool includeAnalytics,
    String? developerName,
    String? contactNumber,
  }) {
    final bundleId = 'com.example.${appName.replaceAll('_', '')}';
    final content = StringBuffer('''
app:
  name: ${_toTitleCase(appName)}
  bundle_id: $bundleId
  platforms: [ios, android, web]
  primary_color: '#6200EA'
''');

    if (developerName != null) {
      content.writeln("  developer_name: $developerName");
    }
    if (contactNumber != null) {
      content.writeln("  contact_number: $contactNumber");
    }

    content.writeln('''
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

rbac:
  roles: [admin, user, guest]
  default_role: user
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

  void _writeUiConfigYaml(String dir, String appName) {
    final assetsDir = Directory(p.join(dir, 'assets'));
    if (!assetsDir.existsSync()) {
      assetsDir.createSync(recursive: true);
    }

    final formattedName = _toTitleCase(appName);
    final yamlContent = '''global:
  app_name: "$formattedName"
  primary_color: "#6200EA"       # Default primary purple
  secondary_color: "#03DAC6"     # Teal

onboarding:
  show_skip: true
  show_indicators: true
  pages:
    - title: "Welcome to $formattedName"
      description: "Generate fully decoupled, standardized Flutter modules instantly. Complete with clean repositories, providers, and models."
      icon: "architecture"
      theme_color: "#6200EA"
      gradient_colors:
        - "#6200EA"
        - "#03DAC6"
    - title: "Global Scaling Monorepos"
      description: "Manage multiple production apps, administrative tools, and internal UI libraries seamlessly in one Melos workspace."
      icon: "layers"
      theme_color: "#11998E"
      gradient_colors:
        - "#11998E"
        - "#38EF7D"
    - title: "Unified payment integrations"
      description: "One-click Razorpay, Stripe, and Apple IAP module provisioning. Spend time building value, not payment logic."
      icon: "wallet"
      theme_color: "#B91D73"
      gradient_colors:
        - "#F953C6"
        - "#B91D73"

login:
  title: "Secure Portal"
  subtitle: "Access your premium $formattedName workspace"
  show_social_logins: true
  allow_sign_up: true
  logo_icon: "bolt"
  allow_google_login: true
  allow_apple_login: true
  allow_forgot_password: true

subscription:
  title: "Accelerate Development"
  subtitle: "Upgrade to one of our optimized plans for production-grade scale and performance."
  currency: "INR"
  show_checkout_button: true
  plans:
    - name: "Hobbyist"
      price: 0
      currency: "INR"
      period: "free"
      description: "Perfect for learning and building personal prototypes."
      features:
        - "1 Monorepo Workspace"
        - "Basic Local Storage Providers"
        - "Console Analytics Logging"
        - "Community Support"
      gradient_colors:
        - "#8E2DE2"
        - "#4A00E0"
      is_popular: false
    - name: "Pro Developer"
      price: 899
      currency: "INR"
      period: "mo"
      description: "Our most popular offering for serious production projects."
      features:
        - "Unlimited Monorepo Workspaces"
        - "Supabase Backend Provisioning"
        - "Stripe + Razorpay Payment Modules"
        - "Full Sentry + PostHog Diagnostics"
        - "Priority Support 24/7"
      gradient_colors:
        - "#6200EA"
        - "#03DAC6"
      is_popular: true
    - name: "Enterprise Hub"
      price: 3999
      currency: "INR"
      period: "mo"
      description: "For teams requiring customized integrations, performance SLAs, and dedicated compute."
      features:
        - "Dedicated Premium Support Representative"
        - "Custom Gateway Providers Integration"
        - "SLA Guaranteed Database Clusters"
        - "Tailored Workspace Integrations"
        - "White-glove melos migrations"
      gradient_colors:
        - "#11998E"
        - "#38EF7D"
      is_popular: false

profile:
  title: "My Account"
  premium_tier_name: "Pro Developer"
  show_billing_history: true
  show_preferences: true
  show_support: true
  help_center_url: "https://support.flutterforge.com"
  allow_edit_profile: true
  allow_logout: true
''';

    File(p.join(assetsDir.path, 'ui_config.yaml')).writeAsStringSync(yamlContent);
  }

  void _updatePubspecAssets(String dir) {
    final file = File(p.join(dir, 'pubspec.yaml'));
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    // Check if assets/ui_config.yaml is already present
    if (content.contains('assets/ui_config.yaml')) return;

    // Find the 'flutter:' section
    if (content.contains('flutter:')) {
      final flutterIndex = content.indexOf('flutter:');
      final nextLineIndex = content.indexOf('\n', flutterIndex);
      if (nextLineIndex != -1) {
        content = content.replaceRange(
          nextLineIndex,
          nextLineIndex,
          '\n  assets:\n    - assets/ui_config.yaml',
        );
      }
    } else {
      content += '\nflutter:\n  assets:\n    - assets/ui_config.yaml\n';
    }

    file.writeAsStringSync(content);
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

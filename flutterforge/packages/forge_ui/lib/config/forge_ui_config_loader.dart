import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'forge_ui_config.dart';

/// Utility to load, parse, and safely cast dynamic values from YAML files.
class ForgeUIConfigLoader {
  
  /// Parse a YAML string into a ForgeUIConfig object.
  static ForgeUIConfig parse(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! YamlMap) {
        return ForgeUIConfig.fallback();
      }

      // 1. Global config
      final globalYaml = doc['global'];
      final globalConfig = _parseGlobal(globalYaml);

      // 2. Onboarding config
      final onboardingYaml = doc['onboarding'];
      final onboardingConfig = _parseOnboarding(onboardingYaml);

      // 3. Login config
      final loginYaml = doc['login'];
      final loginConfig = _parseLogin(loginYaml);

      // 4. Subscription config
      final subscriptionYaml = doc['subscription'];
      final subscriptionConfig = _parseSubscription(subscriptionYaml);

      // 5. Profile config
      final profileYaml = doc['profile'];
      final profileConfig = _parseProfile(profileYaml);

      // 6. Features config
      final featuresYaml = doc['features'];
      final featuresMap = _parseFeatures(featuresYaml);

      return ForgeUIConfig(
        global: globalConfig,
        onboarding: onboardingConfig,
        login: loginConfig,
        subscription: subscriptionConfig,
        profile: profileConfig,
        features: featuresMap,
      );
    } catch (e) {
      // Return default fallback if parsing fails to avoid app crashes
      debugPrint('Error parsing ui_config.yaml: $e. Falling back to default settings.');
      return ForgeUIConfig.fallback();
    }
  }

  static ForgeGlobalConfig _parseGlobal(dynamic yaml) {
    if (yaml is! YamlMap) return const ForgeGlobalConfig();
    
    return ForgeGlobalConfig(
      appName: yaml['app_name']?.toString() ?? 'FlutterForge',
      primaryColor: parseHexColor(yaml['primary_color']?.toString()),
      secondaryColor: parseHexColor(yaml['secondary_color']?.toString()),
    );
  }

  static ForgeOnboardingConfig _parseOnboarding(dynamic yaml) {
    if (yaml is! YamlMap) return ForgeOnboardingConfig.fallback();

    final showSkip = yaml['show_skip'] is bool ? yaml['show_skip'] as bool : true;
    final showIndicators = yaml['show_indicators'] is bool ? yaml['show_indicators'] as bool : true;
    final pagesList = yaml['pages'];
    
    if (pagesList is! YamlList) {
      return ForgeOnboardingConfig.fallback();
    }

    final List<OnboardingPageConfig> parsedPages = [];
    for (final page in pagesList) {
      if (page is YamlMap) {
        parsedPages.add(OnboardingPageConfig(
          title: page['title']?.toString() ?? 'Untitled',
          description: page['description']?.toString() ?? '',
          icon: _parseIcon(page['icon']?.toString()),
          themeColor: parseHexColor(page['theme_color']?.toString()) ?? Colors.deepPurple,
          backgroundGradient: _parseColorList(page['gradient_colors']) ?? [Colors.deepPurple, Colors.indigo],
        ));
      }
    }

    return ForgeOnboardingConfig(
      showSkip: showSkip,
      showIndicators: showIndicators,
      pages: parsedPages.isEmpty ? ForgeOnboardingConfig.fallback().pages : parsedPages,
    );
  }

  static ForgeLoginConfig _parseLogin(dynamic yaml) {
    if (yaml is! YamlMap) return const ForgeLoginConfig();

    return ForgeLoginConfig(
      title: yaml['title']?.toString(),
      subtitle: yaml['subtitle']?.toString(),
      showSocialLogins: yaml['show_social_logins'] is bool ? yaml['show_social_logins'] as bool : true,
      allowSignUp: yaml['allow_sign_up'] is bool ? yaml['allow_sign_up'] as bool : true,
      logoIcon: _parseIcon(yaml['logo_icon']?.toString(), defaultIcon: Icons.bolt_rounded),
      allowGoogleLogin: yaml['allow_google_login'] is bool ? yaml['allow_google_login'] as bool : true,
      allowAppleLogin: yaml['allow_apple_login'] is bool ? yaml['allow_apple_login'] as bool : true,
      allowForgotPassword: yaml['allow_forgot_password'] is bool ? yaml['allow_forgot_password'] as bool : true,
      requireName: yaml['require_name'] is bool ? yaml['require_name'] as bool : false,
      requireContactNumber: yaml['require_contact_number'] is bool ? yaml['require_contact_number'] as bool : false,
    );
  }

  static ForgeSubscriptionConfig _parseSubscription(dynamic yaml) {
    if (yaml is! YamlMap) return ForgeSubscriptionConfig.fallback();

    final title = yaml['title']?.toString();
    final subtitle = yaml['subtitle']?.toString();
    final currency = yaml['currency']?.toString() ?? 'INR';
    final showCheckoutButton = yaml['show_checkout_button'] is bool ? yaml['show_checkout_button'] as bool : true;
    final plansList = yaml['plans'];

    if (plansList is! YamlList) {
      return ForgeSubscriptionConfig.fallback();
    }

    final List<SubscriptionPlanConfig> parsedPlans = [];
    for (final plan in plansList) {
      if (plan is YamlMap) {
        final featuresList = plan['features'];
        final List<String> parsedFeatures = [];
        if (featuresList is YamlList) {
          for (final f in featuresList) {
            parsedFeatures.add(f.toString());
          }
        }

        parsedPlans.add(SubscriptionPlanConfig(
          name: plan['name']?.toString() ?? 'Standard',
          price: double.tryParse(plan['price']?.toString() ?? '0') ?? 0.0,
          currency: plan['currency']?.toString() ?? currency,
          period: plan['period']?.toString() ?? 'mo',
          description: plan['description']?.toString() ?? '',
          features: parsedFeatures,
          gradientColors: _parseColorList(plan['gradient_colors']) ?? [Colors.blue, Colors.purple],
          isPopular: plan['is_popular'] is bool ? plan['is_popular'] as bool : false,
        ));
      }
    }

    return ForgeSubscriptionConfig(
      title: title,
      subtitle: subtitle,
      currency: currency,
      showCheckoutButton: showCheckoutButton,
      plans: parsedPlans.isEmpty ? ForgeSubscriptionConfig.fallback().plans : parsedPlans,
    );
  }

  static ForgeProfileConfig _parseProfile(dynamic yaml) {
    if (yaml is! YamlMap) return const ForgeProfileConfig();

    return ForgeProfileConfig(
      title: yaml['title']?.toString() ?? 'Profile',
      premiumTierName: yaml['premium_tier_name']?.toString() ?? 'Pro Developer',
      showBillingHistory: yaml['show_billing_history'] is bool ? yaml['show_billing_history'] as bool : true,
      showPreferences: yaml['show_preferences'] is bool ? yaml['show_preferences'] as bool : true,
      showSupport: yaml['show_support'] is bool ? yaml['show_support'] as bool : true,
      helpCenterUrl: yaml['help_center_url']?.toString(),
      allowEditProfile: yaml['allow_edit_profile'] is bool ? yaml['allow_edit_profile'] as bool : true,
      allowLogout: yaml['allow_logout'] is bool ? yaml['allow_logout'] as bool : true,
    );
  }

  static Map<String, bool> _parseFeatures(dynamic yaml) {
    final Map<String, bool> features = {};
    if (yaml is! YamlMap) return features;

    for (final entry in yaml.entries) {
      final key = entry.key?.toString();
      final value = entry.value;
      if (key != null && value is bool) {
        features[key] = value;
      } else if (key != null && value is YamlMap) {
        for (final subEntry in value.entries) {
          final subKey = subEntry.key?.toString();
          final subValue = subEntry.value;
          if (subKey != null && subValue is bool) {
            features['${key}_$subKey'] = subValue;
          }
        }
      }
    }
    return features;
  }

  // --- Parsing Helpers ---

  static IconData _parseIcon(String? name, {IconData defaultIcon = Icons.star_rounded}) {
    switch (name?.toLowerCase()) {
      case 'bolt': return Icons.bolt_rounded;
      case 'architecture': return Icons.architecture_rounded;
      case 'layers': return Icons.layers_outlined;
      case 'wallet':
      case 'payment':
      case 'card':
        return Icons.account_balance_wallet_outlined;
      case 'person':
      case 'profile':
      case 'user':
        return Icons.person_outline_rounded;
      case 'security':
      case 'shield':
        return Icons.shield_outlined;
      case 'settings':
      case 'gear':
        return Icons.settings_outlined;
      case 'help':
      case 'support':
      case 'question':
        return Icons.help_outline_rounded;
      case 'insights': return Icons.insights_rounded;
      case 'show_chart': return Icons.show_chart_rounded;
      case 'psychology': return Icons.psychology_rounded;
      default: return defaultIcon;
    }
  }

  static List<Color>? _parseColorList(dynamic yaml) {
    if (yaml is! YamlList) return null;
    final List<Color> colors = [];
    for (final element in yaml) {
      final color = parseHexColor(element?.toString());
      if (color != null) {
        colors.add(color);
      }
    }
    return colors.isNotEmpty ? colors : null;
  }
}

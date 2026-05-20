import 'package:flutter/material.dart';

/// Helper to safely parse color strings (e.g. '#6200EA' or '0xFF6200EA') into Color objects.
Color? parseHexColor(String? hexString) {
  if (hexString == null) return null;
  String cleanHex = hexString.replaceAll('#', '').trim();
  if (cleanHex.length == 6) {
    cleanHex = 'FF$cleanHex';
  }
  final intValue = int.tryParse(cleanHex, radix: 16);
  return intValue != null ? Color(intValue) : null;
}

/// Root configuration holding all screen configurations
class ForgeUIConfig {
  final ForgeGlobalConfig global;
  final ForgeOnboardingConfig onboarding;
  final ForgeLoginConfig login;
  final ForgeSubscriptionConfig subscription;
  final ForgeProfileConfig profile;

  const ForgeUIConfig({
    required this.global,
    required this.onboarding,
    required this.login,
    required this.subscription,
    required this.profile,
  });

  /// Default fallback configuration
  factory ForgeUIConfig.fallback() {
    return ForgeUIConfig(
      global: const ForgeGlobalConfig(),
      onboarding: ForgeOnboardingConfig.fallback(),
      login: const ForgeLoginConfig(),
      subscription: ForgeSubscriptionConfig.fallback(),
      profile: const ForgeProfileConfig(),
    );
  }
}

/// Global styling and variables
class ForgeGlobalConfig {
  final String appName;
  final Color? primaryColor;
  final Color? secondaryColor;

  const ForgeGlobalConfig({
    this.appName = 'FlutterForge',
    this.primaryColor,
    this.secondaryColor,
  });
}

/// Onboarding page item configuration
class OnboardingPageConfig {
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final List<Color> backgroundGradient;

  const OnboardingPageConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    required this.backgroundGradient,
  });
}

/// Onboarding screen-specific configuration
class ForgeOnboardingConfig {
  final bool showSkip;
  final bool showIndicators;
  final List<OnboardingPageConfig> pages;

  const ForgeOnboardingConfig({
    this.showSkip = true,
    this.showIndicators = true,
    required this.pages,
  });

  factory ForgeOnboardingConfig.fallback() {
    return const ForgeOnboardingConfig(
      showSkip: true,
      showIndicators: true,
      pages: [
        OnboardingPageConfig(
          title: 'Architected for Scale',
          description: 'FlutterForge generates production-ready architecture with clean separation of concerns, robust providers, and standardized modules.',
          icon: Icons.architecture_rounded,
          themeColor: Colors.deepPurple,
          backgroundGradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        OnboardingPageConfig(
          title: 'Monorepo Strategy',
          description: 'Manage multiple mobile apps, admin dashboards, shared UI libraries, and backends seamlessly inside a unified Melos workspace.',
          icon: Icons.layers_outlined,
          themeColor: Colors.teal,
          backgroundGradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        OnboardingPageConfig(
          title: 'Unified Payments & Analytics',
          description: 'Plug-and-play Razorpay, Stripe, Sentry, and PostHog in minutes. Focus entirely on product value, not infrastructure setup.',
          icon: Icons.account_balance_wallet_outlined,
          themeColor: Colors.pink,
          backgroundGradient: [Color(0xFFF953C6), Color(0xFFB91D73)],
        ),
      ],
    );
  }
}

/// Authentication screen configuration
class ForgeLoginConfig {
  final String? title;
  final String? subtitle;
  final bool showSocialLogins;
  final bool allowSignUp;
  final IconData logoIcon;
  final bool allowGoogleLogin;
  final bool allowAppleLogin;
  final bool allowForgotPassword;

  const ForgeLoginConfig({
    this.title,
    this.subtitle,
    this.showSocialLogins = true,
    this.allowSignUp = true,
    this.logoIcon = Icons.bolt_rounded,
    this.allowGoogleLogin = true,
    this.allowAppleLogin = true,
    this.allowForgotPassword = true,
  });
}

/// Custom subscription plan configuration
class SubscriptionPlanConfig {
  final String name;
  final double price;
  final String currency;
  final String period;
  final String description;
  final List<String> features;
  final List<Color> gradientColors;
  final bool isPopular;

  const SubscriptionPlanConfig({
    required this.name,
    required this.price,
    required this.currency,
    required this.period,
    required this.description,
    required this.features,
    required this.gradientColors,
    this.isPopular = false,
  });
}

/// Subscription screen configuration
class ForgeSubscriptionConfig {
  final String? title;
  final String? subtitle;
  final String currency;
  final bool showCheckoutButton;
  final List<SubscriptionPlanConfig> plans;

  const ForgeSubscriptionConfig({
    this.title,
    this.subtitle,
    this.currency = 'INR',
    this.showCheckoutButton = true,
    required this.plans,
  });

  factory ForgeSubscriptionConfig.fallback() {
    return const ForgeSubscriptionConfig(
      title: 'Unlock Full Potential',
      subtitle: 'Pick the perfect plan to accelerate your development workflows with production-ready architecture.',
      currency: 'INR',
      showCheckoutButton: true,
      plans: [
        SubscriptionPlanConfig(
          name: 'Starter',
          price: 0,
          currency: 'INR',
          period: 'free',
          description: 'Perfect for exploring and building basic prototypes.',
          features: [
            '1 Active Project',
            'Supabase Community Dev Database',
            'Basic Console Analytics',
            'Community Support',
          ],
          gradientColors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        SubscriptionPlanConfig(
          name: 'Pro',
          price: 999,
          currency: 'INR',
          period: 'mo',
          description: 'Ideal for serious developers and growing applications.',
          features: [
            'Unlimited Projects',
            'Supabase Standard Backend Access',
            'Razorpay + Stripe + Apple IAP Modules',
            'Full PostHog & Sentry Integrations',
            'Priority 24/7 Support',
          ],
          gradientColors: [Color(0xFFF953C6), Color(0xFFB91D73)],
          isPopular: true,
        ),
        SubscriptionPlanConfig(
          name: 'Enterprise',
          price: 4999,
          currency: 'INR',
          period: 'mo',
          description: 'For teams requiring dedicated performance, SLAs, and scale.',
          features: [
            'Dedicated Premium Support Manager',
            'Custom Third-Party Integrations',
            'High-Availability Database Clusters',
            'Full Performance Diagnostics SLA',
            'Tailored Team Workspaces',
          ],
          gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
      ],
    );
  }
}

/// User Profile screen configuration
class ForgeProfileConfig {
  final String? title;
  final String? premiumTierName;
  final bool showBillingHistory;
  final bool showPreferences;
  final bool showSupport;
  final String? helpCenterUrl;
  final bool allowEditProfile;
  final bool allowLogout;

  const ForgeProfileConfig({
    this.title = 'Profile',
    this.premiumTierName = 'Pro Developer',
    this.showBillingHistory = true,
    this.showPreferences = true,
    this.showSupport = true,
    this.helpCenterUrl,
    this.allowEditProfile = true,
    this.allowLogout = true,
  });
}

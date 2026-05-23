# ⚡ FlutterForge — Complete Setup Guide

This guide walks you through every step to get FlutterForge running, from zero to a working app with auth, payments, and analytics.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install FlutterForge CLI](#2-install-flutterforge-cli)
3. [Create a New Project](#3-create-a-new-project)
4. [Configure Supabase (Backend)](#4-configure-supabase-backend)
5. [Configure Razorpay (Payments — India)](#5-configure-razorpay-payments--india)
6. [Configure Stripe (Payments — International)](#6-configure-stripe-payments--international)
7. [Configure PostHog (Analytics)](#7-configure-posthog-analytics)
8. [Configure Sentry (Crash Monitoring)](#8-configure-sentry-crash-monitoring)
9. [Platform Setup — Android](#9-platform-setup--android)
10. [Platform Setup — iOS](#10-platform-setup--ios)
11. [Platform Setup — Web](#11-platform-setup--web)
12. [Running the App](#12-running-the-app)
13. [Production Checklist](#13-production-checklist)
14. [Monorepo Commands](#14-monorepo-commands)
15. [Role-Based Access Control (RBAC)](#15-role-based-access-control-rbac)
16. [CLI Advanced Usage](#16-cli-advanced-usage)
17. [Project Structure](#17-project-structure)
18. [Troubleshooting](#18-troubleshooting)

---

## 1. Prerequisites

Install these tools before starting:

### Flutter SDK
```bash
# macOS/Linux
git clone https://github.com/flutter/flutter.git ~/flutter
export PATH="$PATH:$HOME/flutter/bin"   # Add to ~/.zshrc or ~/.bashrc

# Windows: Download from flutter.dev/docs/get-started/install/windows
# Then add C:\flutter\bin to your PATH in System Environment Variables

# Verify
flutter doctor
flutter --version   # Should be ≥ 3.10.0
```

### Dart SDK
Dart is bundled with Flutter. No separate install needed.

### Melos (monorepo manager)
```bash
dart pub global activate melos
# Add to PATH: export PATH="$PATH:$HOME/.pub-cache/bin"
melos --version
```

### Android Studio (for Android)
1. Download from [developer.android.com/studio](https://developer.android.com/studio)
2. Install **Android SDK** (API Level 33+)
3. Install **Android Emulator** or connect a real device
4. Run `flutter doctor` — follow its suggestions

### Xcode (for iOS — macOS only)
```bash
# Install Xcode from Mac App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license

# Install CocoaPods
sudo gem install cocoapods
# OR with Homebrew:
brew install cocoapods

pod --version   # Should be ≥ 1.13.0
```

---

## 2. Install FlutterForge CLI

```bash
# Clone the FlutterForge repo
git clone https://github.com/yourorg/flutterforge.git
cd flutterforge

# Install the forge CLI globally
cd forge_cli
dart pub get
dart pub global activate --source path .

# Verify
forge --help
```

---

## 3. Create a New Project

```bash
# Blank project
forge create my_app

# SaaS preset (auth + payments + analytics pre-wired)
forge create my_app --preset saas

# E-commerce preset
forge create my_app --preset ecommerce --payments

# With Firebase instead of Supabase
forge create my_app --backend firebase

cd my_app
```

This creates:
```
my_app/
├── lib/
│   ├── main.dart          ← Generated, safe to edit
│   ├── routes.dart        ← Generated, safe to edit
│   └── features/          ← Your feature code goes here
├── forge.yaml             ← Your config file
├── .env.dev.json          ← Fill in your credentials (never commit)
├── .env.prod.json         ← Production credentials (never commit)
└── pubspec.yaml
```

### Check your setup
```bash
forge doctor
```

---

## 4. Configure Supabase (Backend)

Supabase provides auth, Postgres DB, storage, and edge functions.

### Step 1 — Create a Supabase project
1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Choose a name, database password, and region (choose closest to your users)
3. Wait ~2 minutes for provisioning

### Step 2 — Get your credentials
1. Go to **Settings → API**
2. Copy **Project URL** → `SUPABASE_URL`
3. Copy **anon/public key** → `SUPABASE_ANON_KEY`

### Step 3 — Add to .env.dev.json
```json
{
  "SUPABASE_URL": "https://abcdefghijklm.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Step 4 — Enable Auth Providers in Supabase Dashboard
Go to **Authentication → Providers**:

**Email (enabled by default):**
- Toggle **Enable email confirmations** as needed

**Google:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a project → **APIs & Services → Credentials → Create OAuth 2.0 Client ID**
3. Add authorized redirect URIs:
   - `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
4. Copy **Client ID** and **Client Secret** into Supabase → Auth → Providers → Google

**Apple (iOS only):**
1. You need an **Apple Developer account** ($99/year)
2. Go to [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles**
3. Register an App ID with **Sign in with Apple** enabled
4. Create a **Services ID** for web redirect
5. Add credentials in Supabase → Auth → Providers → Apple

### Step 5 — Set up Row Level Security (RLS)
In Supabase → **SQL Editor**, run:
```sql
-- Example: users can only read their own data
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id);
```

---

## 5. Configure Razorpay (Payments — India)

Razorpay supports UPI, Cards, NetBanking, and Wallets for Indian users.

### Step 1 — Create a Razorpay account
1. Go to [razorpay.com](https://razorpay.com) → **Sign Up**
2. Complete KYC (required for live payments — takes 1-3 days)

### Step 2 — Get API keys
1. Dashboard → **Settings → API Keys**
2. Click **Generate Test Key**
3. Copy **Key ID** (starts with `rzp_test_`) → `RAZORPAY_KEY_ID`
4. Copy **Key Secret** → store on your BACKEND ONLY (never in app)

### Step 3 — Add to .env.dev.json
```json
{
  "RAZORPAY_KEY_ID": "rzp_test_xxxxxxxxxxxxxxxx"
}
```

### Step 4 — Android setup
In `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 21        // Required by razorpay_flutter
        targetSdkVersion 33
    }
}
```

In `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest>
  <application>
    <!-- Add inside <application> tag -->
    <activity
      android:name="com.razorpay.CheckoutActivity"
      android:configChanges="keyboard|keyboardHidden|orientation|screenSize"
      android:theme="@style/CheckoutTheme"
      android:exported="false" />
  </application>

  <!-- Add outside <application> tag -->
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
</manifest>
```

### Step 5 — iOS setup
In `ios/Runner/Info.plist`, add:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>

<!-- For UPI intent apps -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>phonepe</string>
  <string>tez</string>
  <string>paytm</string>
  <string>bhim</string>
</array>
```

### Step 6 — Backend order creation (REQUIRED)
**Never create Razorpay orders on the client.** Create on your backend:

```javascript
// Node.js backend example
const Razorpay = require('razorpay');
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,  // NEVER send to client
});

app.post('/api/orders/create', async (req, res) => {
  const order = await razorpay.orders.create({
    amount: req.body.amount,   // In paise (₹999 = 99900)
    currency: 'INR',
    receipt: `receipt_${Date.now()}`,
  });
  res.json({ orderId: order.id });
});

// Verify payment signature
app.post('/api/payments/verify', (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;
  const crypto = require('crypto');
  const sign = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(`${razorpay_order_id}|${razorpay_payment_id}`)
    .digest('hex');
  const isValid = sign === razorpay_signature;
  res.json({ valid: isValid });
});
```

---

## 6. Configure Stripe (Payments — International)

### Step 1 — Create Stripe account
1. Go to [stripe.com](https://stripe.com) → **Sign Up**
2. No KYC needed for test mode

### Step 2 — Get publishable key
1. Dashboard → **Developers → API keys**
2. Copy **Publishable key** (starts with `pk_test_`) → `STRIPE_KEY`
3. Copy **Secret key** → store on your BACKEND ONLY

### Step 3 — Android setup
In `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 21    // Required by flutter_stripe
    }
}
```

In `android/app/src/main/AndroidManifest.xml`:
```xml
<application
  android:name="io.flutter.app.FlutterApplication"
  ...>
```

### Step 4 — iOS setup
In `ios/Runner/AppDelegate.swift`:
```swift
import UIKit
import Flutter
import Stripe

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 5 — Backend PaymentIntent creation
```javascript
app.post('/api/stripe/payment-intent', async (req, res) => {
  const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
  const paymentIntent = await stripe.paymentIntents.create({
    amount: req.body.amount,
    currency: req.body.currency,
    automatic_payment_methods: { enabled: true },
  });
  res.json({ clientSecret: paymentIntent.client_secret });
  // Pass clientSecret as `orderId` to StripeGateway.charge()
});
```

---

## 7. Configure PostHog (Analytics)

### Step 1 — Create PostHog account
1. Go to [posthog.com](https://posthog.com) → **Sign Up** (free up to 1M events/month)
2. Create a project

### Step 2 — Get API key
1. **Project Settings → Project API Key**
2. Copy it → `POSTHOG_API_KEY`

### Step 3 — Uncomment in AnalyticsModule
In `lib/main.dart`, change:
```dart
providers: [AnalyticsProviderType.console],
// to:
providers: [AnalyticsProviderType.posthog, AnalyticsProviderType.console],
posthogApiKey: ForgeEnv.get('POSTHOG_API_KEY'),
```

In `packages/forge_analytics/lib/src/module/analytics_module.dart`, uncomment:
```dart
import 'package:posthog_flutter/posthog_flutter.dart';

Future<dynamic> _initPostHog(String apiKey, String? host) async {
  final config = PostHogConfig(apiKey);
  config.host = host ?? 'https://app.posthog.com';
  await Posthog().setup(config);
  return Posthog();
}
```

### Step 4 — Android setup
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 8. Configure Sentry (Crash Monitoring)

### Step 1 — Create Sentry account
1. Go to [sentry.io](https://sentry.io) → **Sign Up** (free tier: 5K errors/month)
2. Create a **Flutter project**
3. Copy the **DSN** → `SENTRY_DSN`

### Step 2 — Add to pubspec.yaml
```yaml
dependencies:
  sentry_flutter: ^7.18.0
```

### Step 3 — Initialize in main.dart
Wrap `runApp` with Sentry:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = ForgeEnv.get('SENTRY_DSN');
    options.tracesSampleRate = 0.2;   // Sample 20% of transactions
    options.environment = ForgeEnv.current.name;
  },
  appRunner: () => runApp(const MyApp()),
);
```

---

## 9. Platform Setup — Android

### Minimum SDK version
In `android/app/build.gradle`:
```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21        // Required for most forge packages
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true    // Required if you have many dependencies
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### Proguard rules for Razorpay
In `android/app/proguard-rules.pro`:
```
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
```

### Signing for release
```bash
# Generate keystore (do this once, store securely)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Create android/key.properties (never commit this file)
cat > android/key.properties << EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_NAME/upload-keystore.jks
EOF
```

Add to `android/.gitignore`:
```
key.properties
*.jks
```

In `android/app/build.gradle`, reference the keystore:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

---

## 10. Platform Setup — iOS

### Minimum deployment target
In `ios/Podfile`:
```ruby
platform :ios, '14.0'    # Required for flutter_stripe, supabase_flutter
```

### After changing Podfile
```bash
cd ios && pod install && cd ..
```

### App capabilities (in Xcode)
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** → **Signing & Capabilities**
3. Add capabilities:
   - **Sign In with Apple** (if using Apple auth)
   - **Push Notifications** (if using push)
   - **In-App Purchase** (if using IAP)

### Info.plist additions
```xml
<!-- For Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Get from GoogleService-Info.plist → REVERSED_CLIENT_ID -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>

<!-- For Razorpay UPI -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>phonepe</string>
  <string>tez</string>
  <string>paytm</string>
  <string>bhim</string>
</array>

<!-- Camera/Photo access (if using file upload) -->
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) needs camera access to upload photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>$(PRODUCT_NAME) needs photo access to upload images.</string>
```

### Podfile troubleshooting
```bash
# If pod install fails
cd ios
pod deintegrate
pod cache clean --all
pod install

# If still failing
rm -rf Pods Podfile.lock
flutter clean
flutter pub get
pod install
```

---

## 11. Platform Setup — Web

### Enable web support
```bash
flutter config --enable-web
flutter create . --platforms web   # Adds web/ folder
```

### CORS for Supabase
In Supabase Dashboard → **API → CORS allowed origins**, add:
```
http://localhost:3000
https://yourapp.com
```

### index.html additions
In `web/index.html`, add before `</body>`:
```html
<!-- For Stripe.js -->
<script src="https://js.stripe.com/v3/"></script>

<!-- For Google Sign-In -->
<meta name="google-signin-client_id" content="YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com">
```

### Building for web
```bash
flutter build web --dart-define-from-file=.env.prod.json
# Output in build/web/ — deploy to Firebase Hosting, Vercel, etc.
```

---

## 12. Running the App

### Development
```bash
# Run on Android emulator / connected device
flutter run --dart-define-from-file=.env.dev.json

# Run on iOS simulator (macOS only)
flutter run -d iPhone --dart-define-from-file=.env.dev.json

# Run on web (Chrome)
flutter run -d chrome --dart-define-from-file=.env.dev.json

# Run with specific flavor
flutter run --dart-define-from-file=.env.dev.json --dart-define=FORGE_ENV=dev
```

### Building for release
```bash
# Android APK
flutter build apk --dart-define-from-file=.env.prod.json --release

# Android App Bundle (for Play Store)
flutter build appbundle --dart-define-from-file=.env.prod.json --release

# iOS (macOS only)
flutter build ipa --dart-define-from-file=.env.prod.json --release

# Web
flutter build web --dart-define-from-file=.env.prod.json --release
```

---

## 13. Production Checklist

Before going live, verify each item:

**Security**
- [ ] `.env.*.json` files are in `.gitignore` (never committed)
- [ ] Razorpay secret key is ONLY on backend
- [ ] Stripe secret key is ONLY on backend
- [ ] Supabase Row Level Security (RLS) is enabled on all tables
- [ ] All backend API endpoints are authenticated

**Payments**
- [ ] Switch Razorpay key from `rzp_test_` to `rzp_live_`
- [ ] Switch Stripe key from `pk_test_` to `pk_live_`
- [ ] Payment signature verification is on your backend
- [ ] Webhook endpoints are configured (Razorpay Dashboard → Webhooks)

**Analytics**
- [ ] Remove `AnalyticsProviderType.console` from prod
- [ ] PostHog project switched to production
- [ ] Sentry `tracesSampleRate` set to 0.1–0.2 (not 1.0)

**App stores**
- [ ] Android keystore stored safely (separate from code)
- [ ] iOS provisioning profile and certificates set up
- [ ] App icons and splash screens added

---

## 14. Monorepo Commands

```bash
# Bootstrap all packages (run once after clone)
melos bootstrap

# Run all tests
melos test

# Analyze all packages
melos analyze

# Format all code
melos format

# Run build_runner in all packages (generates Isar schemas, etc.)
melos generate

# Clean all packages
melos clean

# Work on a specific package
cd packages/forge_backend
flutter test
```

---

## 15. Role-Based Access Control (RBAC)

FlutterForge includes a lightweight RBAC system built into `forge_core`.

### ForgeRole
Define your roles as `ForgeRole` objects. Default roles are `admin`, `user`, and `guest`.
```dart
final role = ForgeRole.admin;
```

### UI-Level Protection: RBACGate
Wrap widgets that should only be visible to specific roles:
```dart
RBACGate(
  currentRole: user?.role,
  allowedRoles: const [ForgeRole.admin],
  child: AdminDashboard(),
)
```

### Route-Level Protection: ForgeRoleGuard
Use the guard in your `go_router` redirect logic:
```dart
GoRoute(
  path: '/admin',
  redirect: (context, state) => ForgeRoleGuard.redirect(
    currentRole: currentUser?.role,
    allowedRoles: const [ForgeRole.admin],
    redirectLocation: '/',
  ),
)
```

---

## 16. CLI Advanced Usage

The `forge` CLI is your companion for maintaining FlutterForge projects.

### `forge doctor`
Run this to verify your environment meets all requirements (Flutter, Melos, CocoaPods, etc.) and that your `forge.yaml` is valid.

### `forge generate`
Regenerates `lib/main.dart` based on your `forge.yaml`. Use this when you swap backends, add payment providers, or change analytics config. It also creates a template `lib/routes.dart` if it doesn't exist.

### `forge create <app_name> --preset <preset>`
Scaffolds a new project. 
- **Presets**: `saas`, `marketplace`, `ecommerce`, `blank`.
- **Backend**: `--backend supabase` or `--backend firebase`.

---

## 17. Project Structure

```
flutterforge/
├── melos.yaml                    ← Monorepo config
├── forge.yaml                    ← Your app config
│
├── packages/
│   ├── forge_core/               ← DI, routing, theming, env (REQUIRED)
│   │   └── lib/src/
│   │       ├── di/               ← GetIt service locator
│   │       ├── routing/          ← go_router wrapper
│   │       ├── theme/            ← ForgeTheme (Material 3)
│   │       ├── env/              ← Environment config
│   │       └── error/            ← Global error boundary
│   │
│   ├── forge_backend/            ← Supabase / Firebase abstraction
│   │   └── lib/src/
│   │       ├── interface/        ← BackendService (abstract)
│   │       ├── supabase/         ← Supabase implementation
│   │       └── firebase/         ← Firebase implementation (template)
│   │
│   ├── forge_payments/           ← Razorpay + Stripe + IAP
│   │   └── lib/src/
│   │       ├── interface/        ← PaymentGateway (abstract)
│   │       ├── razorpay/         ← Razorpay implementation
│   │       └── stripe/           ← Stripe implementation
│   │
│   ├── forge_analytics/          ← PostHog + Firebase + Mixpanel
│   │   └── lib/src/
│   │       └── analytics.dart    ← Analytics.track() singleton
│   │
│   └── forge_state/              ← Riverpod + SecureStorage + Cache
│       └── lib/src/
│           ├── providers/        ← authStateProvider, currentUserProvider
│           ├── storage/          ← ForgeStorage (secure + prefs)
│           └── cache/            ← ForgeCache (in-memory + TTL)
│
├── apps/
│   └── example_app/              ← Full working example app
│       └── lib/
│           ├── main.dart
│           ├── routes.dart
│           └── features/
│               ├── auth/         ← Login + Signup screens
│               ├── home/         ← Home screen with payment demo
│               └── profile/      ← Profile + sign out
│
└── forge_cli/                    ← forge CLI tool
    ├── bin/forge.dart            ← forge <command>
    └── lib/src/
        ├── commands/
        │   ├── create_command.dart   ← forge create
        │   ├── generate_command.dart ← forge generate
        │   └── doctor_command.dart   ← forge doctor
        └── config/
            └── forge_config.dart     ← forge.yaml parser
```

---

## 18. Troubleshooting

### `SUPABASE_URL` is empty at runtime
Make sure you run with `--dart-define-from-file`:
```bash
flutter run --dart-define-from-file=.env.dev.json   ✅
flutter run                                           ❌  (env vars missing)
```

### `pod install` fails on iOS
```bash
cd ios
pod deintegrate && pod cache clean --all
pod install --repo-update
```

### Razorpay payment sheet doesn't open on Android
Check `minSdkVersion 21` in `android/app/build.gradle`.

### Google Sign-In fails with `PlatformException`
- Android: Make sure the SHA-1 fingerprint of your debug keystore is added to Google Cloud Console → OAuth client
- iOS: Check `CFBundleURLSchemes` in Info.plist matches your `REVERSED_CLIENT_ID`

### `MissingPluginException` on web
Some packages (razorpay_flutter, sign_in_with_apple) don't support web. Conditionally disable them:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (!kIsWeb) {
  // Razorpay / Apple-specific code
}
```

### Build runner errors
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### `ForgeConfigException: Environment variable not found`
The variable in your `.env.dev.json` doesn't match what the code expects. Check spelling — keys are case-sensitive.

---

## Getting Help

- Open an issue on GitHub
- Check `forge doctor` output
- Join the Discord: discord.gg/flutterforge

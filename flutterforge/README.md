# ⚡ FlutterForge

**The reusable Flutter starter framework.** Swap backends, payment gateways, and analytics providers by changing one config file — zero feature code changes.

```
forge create my_app --preset saas
cd my_app
flutter run --dart-define-from-file=.env.dev.json
```

---

## What's Included

| Package | What it does |
|---|---|
| `forge_core` | DI (GetIt), routing (go_router), theming (Material 3), env config |
| `forge_backend` | Auth + DB + Storage — Supabase or Firebase, same interface |
| `forge_payments` | Razorpay + Stripe + IAP — same `PaymentGateway` interface |
| `forge_analytics` | PostHog + Mixpanel + Firebase — one `Analytics.track()` call |
| `forge_state` | Riverpod providers + SecureStorage + in-memory cache |
| `forge_cli` | `forge create`, `forge generate`, `forge doctor` |

## Quick Start

```bash
# 1. Install CLI
cd forge_cli && dart pub global activate --source path . && cd ..

# 2. Create project
forge create my_app --preset saas
cd my_app

# 3. Add credentials
nano .env.dev.json   # Fill in Supabase URL, Razorpay key, etc.

# 4. Run
flutter run --dart-define-from-file=.env.dev.json
```

## forge.yaml

The single config file that drives everything:

```yaml
app:
  name: MyApp
  bundle_id: com.example.myapp
  platforms: [ios, android, web]

backend:
  provider: supabase        # swap to: firebase
  supabase:
    url: $SUPABASE_URL
    anon_key: $SUPABASE_ANON_KEY

payments:
  providers: [razorpay, stripe]
  razorpay:
    key_id: $RAZORPAY_KEY_ID

analytics:
  providers: [posthog, firebase]
  posthog:
    api_key: $POSTHOG_API_KEY

state:
  manager: riverpod
  local_db: isar
```

Run `forge generate` after editing — it regenerates `main.dart` and routes.

## Full Setup Guide

See **[SETUP.md](./SETUP.md)** for step-by-step instructions including:
- Every platform (Android, iOS, Web)
- All provider dashboards (Supabase, Razorpay, Stripe, PostHog, Sentry)
- Production checklist
- Troubleshooting

## Architecture

```
Your feature code
      │
      ▼
BackendService (abstract)     PaymentGateway (abstract)     Analytics (singleton)
      │                              │                              │
      ▼                              ▼                              ▼
SupabaseBackendService      RazorpayGateway              PostHogProvider
FirebaseBackendService      StripeGateway                FirebaseAnalyticsProvider
                            IAPGateway                   ConsoleProvider (dev)
```

Your app only imports the abstract interfaces. Swap implementations in `main.dart`.

## License

MIT

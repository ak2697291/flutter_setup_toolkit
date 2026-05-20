import 'package:forge_core/forge_core.dart';
import 'package:forge_core/src/forge_module.dart';
import 'package:get_it/get_it.dart';
import '../interface/payment_gateway.dart';
import '../razorpay/razorpay_gateway.dart';
import '../stripe/stripe_gateway.dart';

enum PaymentProvider { razorpay, stripe, iap }

/// PaymentsModule — registers the chosen payment gateway(s) with the DI container.
///
/// In main.dart:
/// ```dart
/// await initServiceLocator(modules: [
///   PaymentsModule(
///     providers: [PaymentProvider.razorpay],
///     razorpayKeyId: ForgeEnv.get('RAZORPAY_KEY_ID'),
///   ),
/// ]);
/// ```
class PaymentsModule implements ForgeModule {
  final List<PaymentProvider> providers;
  final String? razorpayKeyId;
  final String? stripePublishableKey;
  final String? stripeMerchantId;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  const PaymentsModule({
    required this.providers,
    this.razorpayKeyId,
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.stripePublishableKey,
    this.stripeMerchantId,
  });

  @override
  Future<void> register(GetIt sl) async {
    for (final provider in providers) {
      switch (provider) {
        case PaymentProvider.razorpay:
          assert(razorpayKeyId != null,
              'razorpayKeyId is required for Razorpay');
          sl.registerSingleton<PaymentGateway>(
            RazorpayGateway(keyId: razorpayKeyId!,
              supabaseUrl: supabaseUrl!,
              supabaseAnonKey: supabaseAnonKey!,
            ),
            instanceName: 'razorpay',
          );
          // Also register as default if it's the first provider
          if (providers.first == PaymentProvider.razorpay) {
            sl.registerSingleton<PaymentGateway>(
              RazorpayGateway(keyId: razorpayKeyId!,
                supabaseUrl: supabaseUrl!,
                supabaseAnonKey: supabaseAnonKey!,
              ),
            );
          }

        case PaymentProvider.stripe:
          assert(stripePublishableKey != null,
              'stripePublishableKey is required for Stripe');
          sl.registerSingleton<PaymentGateway>(
            StripeGateway(
              publishableKey: stripePublishableKey!,
              merchantId: stripeMerchantId,
            ),
            instanceName: 'stripe',
          );
          if (providers.first == PaymentProvider.stripe) {
            sl.registerSingleton<PaymentGateway>(
              StripeGateway(publishableKey: stripePublishableKey!),
            );
          }

        case PaymentProvider.iap:
          // In-app purchases via in_app_purchase package
          // TODO: Implement IAPGateway
          break;
      }
    }
  }
}

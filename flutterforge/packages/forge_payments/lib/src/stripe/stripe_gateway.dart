import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:forge_core/forge_core.dart';

import '../interface/payment_gateway.dart';

class StripeGateway implements PaymentGateway {
  final String publishableKey;
  final String? merchantId;

  StripeGateway({
    required this.publishableKey,
    this.merchantId,
  }) {
    Stripe.publishableKey = publishableKey;

    if (merchantId != null) {
      Stripe.merchantIdentifier = merchantId!;
    }
  }

  @override
  PaymentProvider get provider => PaymentProvider.stripe;

  @override
  Future<Either<ForgeFailure, PaymentOrder>> createOrder({
    required double amount,
    required String currency,
    String? description,
    Map<String, String>? metadata,
  }) async {
    try {
      // TODO:
      // Call backend API to create PaymentIntent

      final clientSecret =
          metadata?['client_secret'] ??
          'pi_mock_secret_${DateTime.now().millisecondsSinceEpoch}';

      return Right(
        PaymentOrder(
          id: clientSecret,
          amount: amount,
          currency: currency,
          description: description,
        ),
      );
    } catch (e) {
      return Left(
        ForgeFailure.server(
          e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<ForgeFailure, PaymentResult>> startCheckout({
    required PaymentOrder order,
    Map<String, dynamic>? prefill,
  }) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: order.id,

          merchantDisplayName:
              prefill?['merchant_name'] ?? 'Your App',

          customerId: prefill?['customer_id'],

          customerEphemeralKeySecret:
              prefill?['ephemeral_key'],

          applePay: merchantId != null
              ? const PaymentSheetApplePay(
                  merchantCountryCode: 'US',
                )
              : null,

          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'IN',
            testEnv: true,
          ),

          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return Right(
        PaymentResult(
          status: PaymentStatus.success,
          paymentId:
              prefill?['payment_intent_id'] ?? order.id,
          rawData: {
            'client_secret': order.id,
          },
        ),
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return Right(
          PaymentResult(
            status: PaymentStatus.cancelled,
            errorMessage: 'Payment cancelled',
          ),
        );
      }

      return Left(
        ForgeFailure.payment(
          e.error.localizedMessage ??
              'Stripe payment failed',
        ),
      );
    } catch (e) {
      return Left(
        ForgeFailure.payment(
          e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<ForgeFailure, bool>> verifyPayment({
    required String paymentId,
    required String signature,
  }) async {
    try {
      // TODO:
      // Verify via backend webhook/API

      return const Right(true);
    } catch (e) {
      return Left(
        ForgeFailure.payment(
          e.toString(),
        ),
      );
    }
  }

  @override
  Future<Either<ForgeFailure, PaymentResult>> refund({
    required String paymentId,
    double? amount,
  }) async {
    return Left(
      ForgeFailure.server(
        'Refunds must be initiated server-side',
      ),
    );
  }
}
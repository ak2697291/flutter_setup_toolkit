import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:forge_core/forge_core.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../interface/payment_gateway.dart';

class RazorpayGateway implements PaymentGateway {
  final String keyId;

  /// Base URL of your Supabase project, e.g.
  /// "https://<project-ref>.supabase.co"
  final String supabaseUrl;

  /// Supabase anon (or service-role) key for calling Edge Functions.
  final String supabaseAnonKey;

  final Razorpay _razorpay;
  final http.Client _http;

  Completer<PaymentResult>? _completer;

  RazorpayGateway({
    required this.keyId,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    http.Client? httpClient,
  })  : _razorpay = Razorpay(),
        _http = httpClient ?? http.Client() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey' : supabaseAnonKey,
      };

  Uri _fnUri(String functionName) =>
      Uri.parse('$supabaseUrl/functions/v1/$functionName');

  // ---------------------------------------------------------------------------
  // PaymentGateway interface
  // ---------------------------------------------------------------------------

  @override
  PaymentProvider get provider => PaymentProvider.razorpay;

  /// Calls the `razorpay-create-order` Edge Function which talks to the
  /// Razorpay Orders API server-side (keeping the secret key safe).
  @override
  Future<Either<ForgeFailure, PaymentOrder>> createOrder({
    required double amount,
    required String currency,
    String? description,
    Map<String, String>? metadata,
  }) async {
    try {
      final body = jsonEncode({
        // Razorpay expects amount in the smallest currency unit (paise for INR)
        'amount': (amount * 100).toInt(),
        'currency': currency,
        if (description != null) 'description': description,
        if (metadata != null) 'notes': metadata,
      });

      final response = await _http
          .post(_fnUri('razorpay-create-order'), headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return Left(ForgeFailure.server(
          json['error']?.toString() ?? 'Order creation failed',
        ));
      }

      return Right(PaymentOrder(
        id: json['id'] as String,
        amount: amount,
        currency: currency,
        description: description,
      ));
    } on TimeoutException {
      return Left(ForgeFailure.server('Order creation timed out'));
    } catch (e) {
      return Left(ForgeFailure.server(e.toString()));
    }
  }

  /// Opens the Razorpay checkout sheet and waits for the result.
  @override
  Future<Either<ForgeFailure, PaymentResult>> startCheckout({
    required PaymentOrder order,
    Map<String, dynamic>? prefill,
  }) async {
    try {
      _completer = Completer<PaymentResult>();

      final options = <String, dynamic>{
        'key': keyId,
        'amount': (order.amount * 100).toInt(),
        'currency': order.currency,
        'order_id': order.id,
        'name': prefill?['name'] ?? 'Your App',
        'description': order.description ?? 'Payment',
        if (prefill != null)
          'prefill': {
            'name': prefill['name'],
            'email': prefill['email'],
            'contact': prefill['contact'],
          },
      };

      _razorpay.open(options);

      final result = await _completer!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Payment timed out'),
      );

      return Right(result);
    } on TimeoutException catch (e) {
      return Left(ForgeFailure.payment(e.message ?? 'Payment timed out'));
    } catch (e) {
      return Left(ForgeFailure.payment(e.toString()));
    }
  }

  /// Calls the `razorpay-verify-payment` Edge Function which validates the
  /// HMAC-SHA256 signature server-side.
  @override
  Future<Either<ForgeFailure, bool>> verifyPayment({
    required String paymentId,
    required String signature,
    String? orderId,
  }) async {
    try {
      final body = jsonEncode({
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
      });

      final response = await _http
          .post(
            _fnUri('razorpay-verify-payment'),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return Left(ForgeFailure.payment(
          json['error']?.toString() ?? 'Verification failed',
        ));
      }

      return Right(json['verified'] as bool? ?? false);
    } on TimeoutException {
      return Left(ForgeFailure.payment('Verification timed out'));
    } catch (e) {
      return Left(ForgeFailure.payment(e.toString()));
    }
  }

  /// Refunds are always server-side for security. Calls the
  /// `razorpay-refund` Edge Function.
  @override
  Future<Either<ForgeFailure, PaymentResult>> refund({
    required String paymentId,
    double? amount,
  }) async {
    try {
      final body = jsonEncode({
        'payment_id': paymentId,
        if (amount != null) 'amount': (amount * 100).toInt(),
      });

      final response = await _http
          .post(_fnUri('razorpay-refund'), headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return Left(ForgeFailure.server(
          json['error']?.toString() ?? 'Refund failed',
        ));
      }

      return Right(PaymentResult(
        status: PaymentStatus.refunded,
        paymentId: paymentId,
        rawData: json,
      ));
    } on TimeoutException {
      return Left(ForgeFailure.server('Refund request timed out'));
    } catch (e) {
      return Left(ForgeFailure.server(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Razorpay SDK callbacks
  // ---------------------------------------------------------------------------

  void _handleSuccess(PaymentSuccessResponse response) {
    _completer?.complete(PaymentResult(
      status: PaymentStatus.success,
      paymentId: response.paymentId,
      rawData: {
        'orderId': response.orderId,
        'signature': response.signature,
      },
    ));
  }

  void _handleError(PaymentFailureResponse response) {
    _completer?.complete(PaymentResult(
      status: PaymentStatus.failed,
      errorMessage: response.message,
      rawData: {'code': response.code},
    ));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _completer?.complete(PaymentResult(
      status: PaymentStatus.pending,
      rawData: {'walletName': response.walletName},
    ));
  }

  void dispose() {
    _razorpay.clear();
    _http.close();
  }
}
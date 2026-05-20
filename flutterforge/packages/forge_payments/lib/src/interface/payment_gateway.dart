import 'package:dartz/dartz.dart';
import 'package:forge_core/forge_core.dart';

enum PaymentProvider { razorpay, stripe, iap }
enum PaymentStatus { pending, success, failed, cancelled, refunded }

class PaymentOrder {
  final String id;
  final double amount;
  final String currency;
  final String? description;
  final Map<String, String>? metadata;
  const PaymentOrder({required this.id, required this.amount, required this.currency, this.description, this.metadata});
}

class PaymentResult {
  final PaymentStatus status;
  final String? transactionId;
  final String? paymentId;
  final Map<String, dynamic>? rawData;
  final String? errorMessage;
  const PaymentResult({required this.status, this.transactionId, this.paymentId, this.rawData, this.errorMessage});
}

abstract class PaymentGateway {
  PaymentProvider get provider;
  Future<Either<ForgeFailure, PaymentOrder>> createOrder({required double amount, required String currency, String? description, Map<String, String>? metadata});
  Future<Either<ForgeFailure, PaymentResult>> startCheckout({required PaymentOrder order, Map<String, dynamic>? prefill});
  Future<Either<ForgeFailure, bool>> verifyPayment({required String paymentId, required String signature});
  Future<Either<ForgeFailure, PaymentResult>> refund({required String paymentId, double? amount});
}

import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_payments/src/interface/payment_gateway.dart';
import 'package:forge_state/forge_state.dart';
import 'package:forge_ui/config/forge_ui_config.dart';

class ForgeSubscriptionPlan {
  final String name;
  final double price;
  final String currency;
  final String period;
  final String description;
  final List<String> features;
  final List<Color> gradientColors;
  final bool isPopular;

  const ForgeSubscriptionPlan({
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

class ForgeSubscriptionScreen extends ConsumerStatefulWidget {
  final List<ForgeSubscriptionPlan>? plans;
  final void Function(ForgeSubscriptionPlan plan)? onPlanSelected;
  final String? title;
  final String? subtitle;
  final ForgeSubscriptionConfig? config;

  const ForgeSubscriptionScreen({
    super.key,
    this.plans,
    this.onPlanSelected,
    this.title,
    this.subtitle,
    this.config,
  });

  @override
  ConsumerState<ForgeSubscriptionScreen> createState() => _ForgeSubscriptionScreenState();
}

class _ForgeSubscriptionScreenState extends ConsumerState<ForgeSubscriptionScreen> {
  int _selectedTierIndex = 1; // Default to middle plan
  bool _isLoading = false;
  final sl = GetIt.instance;

  ForgeSubscriptionConfig _resolveConfig() {
    if (widget.config != null) return widget.config!;
    try {
      if (GetIt.instance.isRegistered<ForgeUIConfig>()) {
        return GetIt.instance<ForgeUIConfig>().subscription;
      }
    } catch (_) {}
    return ForgeSubscriptionConfig.fallback();
  }

  List<ForgeSubscriptionPlan> _resolvePlans() {
    final subConfig = _resolveConfig();
    return subConfig.plans.map((p) => ForgeSubscriptionPlan(
      name: p.name,
      price: p.price,
      currency: p.currency,
      period: p.period,
      description: p.description,
      features: p.features,
      gradientColors: p.gradientColors,
      isPopular: p.isPopular,
    )).toList();
  }

  late final List<ForgeSubscriptionPlan> _plans = widget.plans ?? _resolvePlans();

  @override
  void initState() {
    super.initState();
    Analytics.track('forge_subscription_screen_viewed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleSubscription(ForgeSubscriptionPlan plan) async {
    // If a custom callback is provided, invoke it instead of standard flow
    if (widget.onPlanSelected != null) {
      widget.onPlanSelected!(plan);
      return;
    }

    if (plan.price == 0) {
      Analytics.track('forge_subscription_tier_selected', {
        'plan': plan.name.toLowerCase(),
        'price': 0,
        'currency': 'INR',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 ${plan.name} selected successfully!'),
          backgroundColor: Colors.purple.shade600,
        ),
      );
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isLoading = true);
    Analytics.track('payment_initiated', {
      'amount': plan.price * 100,
      'currency': plan.currency,
      'gateway': 'razorpay',
      'plan': plan.name.toLowerCase(),
    });

    if (!sl.isRegistered<PaymentGateway>()) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Payments Not Configured'),
              ],
            ),
            content: const Text(
              'This application currently does not have a configured payment gateway.\n\n'
              'To enable subscriptions and checkout flows, configure payments in forge.yaml, add appropriate keys to your environment, and re-generate the project boilerplate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final gateway = sl<PaymentGateway>();
      final user = ref.read(currentUserProvider);

      final orderResult = await gateway.createOrder(
        amount: plan.price,
        currency: plan.currency,
        description: 'FlutterForge ${plan.name} Subscription',
        metadata: {
          'plan': plan.name.toLowerCase(),
          'user_id': user?.id ?? 'anonymous',
        },
      );

      await orderResult.fold(
        (failure) async {
          Analytics.track('payment_failed', {
            'reason': failure.message,
            'plan': plan.name.toLowerCase(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order creation failed: ${failure.message}'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        (order) async {
          final paymentResult = await gateway.startCheckout(
            order: order,
            prefill: {
              'name': user?.displayName ?? 'Valued Customer',
              'email': user?.email ?? 'customer@example.com',
              'contact': '9999999999',
            },
          );

          paymentResult.fold(
            (failure) {
              Analytics.track('payment_failed', {
                'reason': failure.message,
                'plan': plan.name.toLowerCase(),
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment failed: ${failure.message}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            (result) {
              if (result.status == PaymentStatus.success) {
                Analytics.track('payment_success', {
                  'payment_id': result.paymentId,
                  'plan': plan.name.toLowerCase(),
                  'amount': plan.price,
                });

                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Column(
                        children: [
                          Icon(Icons.stars_rounded, size: 64, color: Colors.amber),
                          SizedBox(height: 12),
                          Text('Upgrade Successful!', textAlign: TextAlign.center),
                        ],
                      ),
                      content: Text(
                        'You are now subscribed to the ${plan.name} plan.\nPayment ID: ${result.paymentId}',
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (context.mounted && Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Back to App'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Payment cancelled'),
                    ),
                  );
                }
              }
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    // ignore: deprecated_member_use
                    Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -100,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: activeColor.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: CircleAvatar(
              radius: 220,
              backgroundColor: Colors.purple.withValues(alpha: 0.06),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        widget.title ?? _resolveConfig().title ?? 'Unlock Full Potential',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle ?? _resolveConfig().subtitle ?? 'Pick the perfect plan to accelerate your development workflows with production-ready architecture.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: PageView.builder(
                    itemCount: _plans.length,
                    controller: PageController(viewportFraction: 0.85, initialPage: _selectedTierIndex),
                    onPageChanged: (idx) {
                      setState(() {
                        _selectedTierIndex = idx;
                      });
                    },
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      final isSelected = index == _selectedTierIndex;

                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: isSelected ? 8 : 28,
                        ),
                        child: _SubscriptionCard(
                          plan: plan,
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_plans.length, (index) {
                    final isSelected = index == _selectedTierIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: isSelected ? 24 : 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isSelected ? activeColor : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                if (_resolveConfig().showCheckoutButton) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _handleSubscription(_plans[_selectedTierIndex]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeColor,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _plans[_selectedTierIndex].price == 0
                                    ? 'Get Started for Free'
                                    : 'Subscribe to ${_plans[_selectedTierIndex].name} • ${_plans[_selectedTierIndex].currency == 'INR' ? '₹' : '\$'}${_plans[_selectedTierIndex].price.toInt()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final ForgeSubscriptionPlan plan;
  final bool isSelected;

  const _SubscriptionCard({
    required this.plan,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isSelected
            ? BorderSide(color: colors.primary.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 10,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: plan.gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          if (plan.isPopular)
            Positioned(
              top: 18,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: plan.gradientColors),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  plan.name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      plan.price == 0 ? 'Free' : '${plan.currency == 'INR' ? '₹' : '\$'}${plan.price.toInt()}',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                      ),
                    ),
                    if (plan.price > 0)
                      Text(
                        '/${plan.period}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: plan.features.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, fIdx) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary.withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                plan.features[fIdx],
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

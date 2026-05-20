import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_payments/src/interface/payment_gateway.dart';
import 'package:forge_state/forge_state.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _selectedTierIndex = 1; // Default to Pro (index 1)
  bool _isLoading = false;
  final sl = GetIt.instance;

  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
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
    SubscriptionPlan(
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
    SubscriptionPlan(
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
  ];

  @override
  void initState() {
    super.initState();
    Analytics.track('subscription_screen_viewed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleSubscription(SubscriptionPlan plan) async {
    if (plan.price == 0) {
      // Free plan selection
      Analytics.track('subscription_tier_selected', {
        'plan': plan.name.toLowerCase(),
        'price': 0,
        'currency': 'INR',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Starter tier selected successfully!'),
          backgroundColor: Colors.purple.shade600,
        ),
      );
      context.pop();
      return;
    }

    setState(() => _isLoading = true);
    Analytics.track('payment_initiated', {
      'amount': plan.price * 100, // in paise
      'currency': plan.currency,
      'gateway': 'razorpay',
      'plan': plan.name.toLowerCase(),
    });

    try {
      final gateway = sl<PaymentGateway>();
      final user = ref.read(currentUserProvider);

      // STEP 1: Create Order
      final orderResult = await gateway.createOrder(
        amount: plan.price.toDouble(),
        currency: plan.currency,
        description: 'FlutterForge ${plan.name} Plan Subscription',
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
          // STEP 2: Checkout
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
                              Navigator.pop(ctx); // Close dialog
                              context.pop(); // Go back to Home / Profile
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
        title: const Text('Upgrade Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Gradient decoration
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.background,
                    Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
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
              backgroundColor: activeColor.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: CircleAvatar(
              radius: 220,
              backgroundColor: Colors.purple.withOpacity(0.06),
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
                        'Unlock Full Potential',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick the perfect plan to accelerate your development workflows with production-ready architecture.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Horizontal Page View for Subscription Cards
                Expanded(
                  child: PageView.builder(
                    itemCount: _plans.length,
                    controller: PageController(viewportFraction: 0.85, initialPage: 1),
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

                // Smooth Dot indicators
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
                        color: isSelected ? activeColor : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Master checkout action button
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
                                  : 'Subscribe to ${_plans[_selectedTierIndex].name} • ${_plans[_selectedTierIndex].price == 999 ? '₹999' : '₹4,999'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlan {
  final String name;
  final int price;
  final String currency;
  final String period;
  final String description;
  final List<String> features;
  final List<Color> gradientColors;
  final bool isPopular;

  SubscriptionPlan({
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

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionPlan plan;
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
            ? BorderSide(color: colors.primary.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Gradient Accent bar at the top
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
                      plan.price == 0 ? 'Free' : '₹${plan.price}',
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
                                color: colors.primary.withOpacity(0.1),
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

import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_payments/src/interface/payment_gateway.dart';
import 'package:forge_state/forge_state.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlutterForge Demo'),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 18),
            ),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.bolt_rounded, color: colors.primary, size: 28),
                    const SizedBox(width: 8),
                    Text('FlutterForge',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Hello, ${user?.email ?? 'Guest'}!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All forge modules are active.',
                    style: TextStyle(color: colors.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription Promo Banner
          _SubscriptionPromoBanner(),
          const SizedBox(height: 24),

          // Module status cards
          Text('Active Modules',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),

          _ModuleStatusTile(
            icon: Icons.cloud_done_outlined,
            title: 'forge_backend',
            subtitle: 'Supabase • Auth + DB + Storage',
            color: Colors.blue,
          ),
          _ModuleStatusTile(
            icon: Icons.payment_outlined,
            title: 'forge_payments',
            subtitle: 'Razorpay • UPI + Cards + Wallets',
            color: Colors.green,
          ),
          _ModuleStatusTile(
            icon: Icons.analytics_outlined,
            title: 'forge_analytics',
            subtitle: 'Console (dev) • PostHog (prod)',
            color: Colors.orange,
          ),
          _ModuleStatusTile(
            icon: Icons.storage_outlined,
            title: 'forge_state',
            subtitle: 'Riverpod + SecureStorage + Cache',
            color: Colors.purple,
          ),
          const SizedBox(height: 24),

          // Payment demo
          Text('Payment Demo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),
          _PaymentDemoCard(),
          const SizedBox(height: 24),

          // Analytics demo
          Text('Analytics Demo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Track events with one line:',
                      style: TextStyle(color: colors.outline)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Analytics.track('demo_button_tapped', {
                        'screen': 'home',
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '✅ Event tracked! Check console logs.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Track Custom Event'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleStatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ModuleStatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.check_circle_rounded,
            color: Colors.green.shade400, size: 20),
      ),
    );
  }
}

class _PaymentDemoCard extends StatefulWidget {
  @override
  State<_PaymentDemoCard> createState() => _PaymentDemoCardState();
}

class _PaymentDemoCardState extends State<_PaymentDemoCard> {
  bool _isLoading = false;
  final sl = GetIt.instance;

  Future<void> _makePayment() async {
    setState(() => _isLoading = true);
    Analytics.track('payment_initiated', {
      'amount': 99900,
      'currency': 'INR',
      'gateway': 'razorpay',
    });

    try {
      final gateway = sl<PaymentGateway>();

// STEP 1: Create order
final orderResult = await gateway.createOrder(
  amount: 999.00,
  currency: 'INR',
  description: 'FlutterForge Pro Plan',
  metadata: {
    'plan': 'pro',
  },
);

await orderResult.fold(
  (failure) async {
    Analytics.track('payment_failed', {
      'reason': failure.message,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order creation failed: ${failure.message}',
          ),
          backgroundColor:
              Theme.of(context).colorScheme.error,
        ),
      );
    }
  },
  (order) async {
    // STEP 2: Start checkout
    final paymentResult =
        await gateway.startCheckout(
      order: order,
      prefill: {
        'name': 'Anil Kumar',
        'email': 'ak2697291@gmail.com',
        'contact': '6266803923',
      },
    );

    paymentResult.fold(
      (failure) {
        Analytics.track('payment_failed', {
          'reason': failure.message,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment failed: ${failure.message}',
              ),
              backgroundColor:
                  Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      (result) {
        if (result.status ==
            PaymentStatus.success) {
          Analytics.track('payment_success', {
            'payment_id': result.paymentId,
          });

          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Payment success! ID: ${result.paymentId}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  result.errorMessage ??
                      'Payment cancelled',
                ),
              ),
            );
          }
        }
      },
    );
  },
);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.currency_rupee, color: colors.primary),
              const SizedBox(width: 8),
              Text('₹999 — Pro Plan',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text('UPI • Cards • NetBanking • Wallets',
                style: TextStyle(color: colors.outline, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _makePayment,
              icon: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.payment_rounded),
              label: const Text('Pay with Razorpay'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionPromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'UPGRADE TO PRO',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock Unlimited Potential',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swap backends, process payments instantly, and access priority modules with premium presets.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore Subscription Plans',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_ui/config/forge_ui_config.dart';

class ForgeOnboardingPageModel {
  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;
  final List<Color> backgroundGradient;

  const ForgeOnboardingPageModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.themeColor,
    required this.backgroundGradient,
  });
}

class ForgeOnboardingScreen extends StatefulWidget {
  final List<ForgeOnboardingPageModel>? pages;
  final ForgeOnboardingConfig? config;
  final VoidCallback onFinish;
  final VoidCallback? onSkip;
  
  const ForgeOnboardingScreen({
    super.key,
    this.pages,
    this.config,
    required this.onFinish,
    this.onSkip,
  });

  @override
  State<ForgeOnboardingScreen> createState() => _ForgeOnboardingScreenState();
}

class _ForgeOnboardingScreenState extends State<ForgeOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  
  ForgeOnboardingConfig _resolveConfig() {
    if (widget.config != null) return widget.config!;
    try {
      if (GetIt.instance.isRegistered<ForgeUIConfig>()) {
        return GetIt.instance<ForgeUIConfig>().onboarding;
      }
    } catch (_) {}
    return ForgeOnboardingConfig.fallback();
  }

  List<ForgeOnboardingPageModel> _resolvePages() {
    final onboardingConfig = _resolveConfig();
    return onboardingConfig.pages.map((p) => ForgeOnboardingPageModel(
      title: p.title,
      description: p.description,
      icon: p.icon,
      themeColor: p.themeColor,
      backgroundGradient: p.backgroundGradient,
    )).toList();
  }

  late final List<ForgeOnboardingPageModel> _pages = widget.pages ?? _resolvePages();

  @override
  void initState() {
    super.initState();
    Analytics.track('forge_onboarding_started', {
      'timestamp': DateTime.now().toIso8601String(),
      'total_pages': _pages.length,
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleSkip() {
    Analytics.track('forge_onboarding_skipped', {
      'last_page': _currentPageIndex,
    });
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onFinish();
    }
  }

  void _handleNext() {
    if (_currentPageIndex == _pages.length - 1) {
      Analytics.track('forge_onboarding_completed', {});
      widget.onFinish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final activePage = _pages[_currentPageIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background Gradient transitions based on active page
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activePage.backgroundGradient.map((c) => c.withValues(alpha: 0.12)).toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Ambient soft light circles for premium backdrop
          Positioned(
            top: -120,
            right: -80,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activePage.themeColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top controls bar: Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPageIndex < _pages.length - 1 && _resolveConfig().showSkip)
                        TextButton(
                          onPressed: _handleSkip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Full screen builder
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPageIndex = idx;
                      });
                      Analytics.track('forge_onboarding_page_changed', {
                        'page_index': idx,
                        'title': _pages[idx].title,
                      });
                    },
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, idx) {
                      final page = _pages[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Premium Illustration container
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: page.backgroundGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: page.themeColor.withValues(alpha: 0.35),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                page.icon,
                                size: 84,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 56),

                            // Page Title
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Page Description
                            Text(
                              page.description,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Lower control section: Page indicators and primary action button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: _resolveConfig().showIndicators
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.end,
                    children: [
                      // Sliding dot indicators
                      if (_resolveConfig().showIndicators)
                        Row(
                          children: List.generate(_pages.length, (idx) {
                            final isActive = idx == _currentPageIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: isActive ? 24 : 8,
                              decoration: BoxDecoration(
                                color: isActive ? activePage.themeColor : theme.colorScheme.outline.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                      // Next or Complete premium button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activePage.themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 4,
                            shadowColor: activePage.themeColor.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPageIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPageIndex == _pages.length - 1 ? Icons.done : Icons.arrow_forward,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import '../../router/app_router.dart';

/// SCR-01 — shown once on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // Slide count — must match the number of title/body pairs in the ARB
  static const _slideCount = 3;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final slides = [
      _Slide(title: l.onboardingTitle1, body: l.onboardingBody1, icon: Icons.sports_tennis),
      _Slide(title: l.onboardingTitle2, body: l.onboardingBody2, icon: Icons.leaderboard),
      _Slide(title: l.onboardingTitle3, body: l.onboardingBody3, icon: Icons.emoji_events),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slideCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slideCount,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (_page < _slideCount - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        context.go(AppRoutes.login);
                      }
                    },
                    child: Text(
                      _page < _slideCount - 1 ? l.actionNext : l.onboardingGetStarted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.title, required this.body, required this.icon});
  final String title;
  final String body;
  final IconData icon;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.icon, size: 96, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(slide.title, style: tt.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(slide.body, style: tt.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

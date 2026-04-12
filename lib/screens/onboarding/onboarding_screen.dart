import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/screens/auth/login_screen.dart';

/// SCR-01 — shown on every launch when unauthenticated.
/// Combines onboarding slides with an embedded login/register panel so
/// returning users can sign in without stepping through the slides first.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            final slidesPanel = _SlidesPanel(
              controller: _controller,
              page: _page,
              slides: slides,
              slideCount: _slideCount,
              onPageChanged: (i) => setState(() => _page = i),
              onNext: _page < _slideCount - 1
                  ? () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              nextLabel: l.actionNext,
            );

            final authPanel = _AuthPanel(l: l);

            if (isWide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: slidesPanel),
                  SizedBox(
                    width: 360,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: authPanel,
                    ),
                  ),
                ],
              );
            }

            // Narrow (phone): onboarding on top, auth card below
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.38,
                  child: slidesPanel,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: authPanel,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slides panel
// ---------------------------------------------------------------------------

class _SlidesPanel extends StatelessWidget {
  const _SlidesPanel({
    required this.controller,
    required this.page,
    required this.slides,
    required this.slideCount,
    required this.onPageChanged,
    required this.onNext,
    required this.nextLabel,
  });

  final PageController controller;
  final int page;
  final List<_Slide> slides;
  final int slideCount;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: slideCount,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) => _SlideView(slide: slides[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slideCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: page == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              if (onNext != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onNext,
                  child: Text(nextLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Auth panel (login/register card)
// ---------------------------------------------------------------------------

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              tabs: [
                Tab(text: l.loginTabLogin),
                Tab(text: l.loginTabRegister),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: const [LoginTab(), RegisterTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide data + view
// ---------------------------------------------------------------------------

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
          Icon(slide.icon, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(slide.title, style: tt.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(slide.body, style: tt.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

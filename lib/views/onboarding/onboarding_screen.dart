import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';

/// オンボーディング(3枚・プライバシー方針を明確に説明)。
/// 区分: 自動（説明のみ）— ユーザー操作なし、価値説明のみ（設計書 Step2 表）。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_OnboardPageData> _pages(AppLocalizations l10n) => [
        _OnboardPageData(
          icon: Icons.dashboard_customize_outlined,
          title: l10n.onboardingPage1Title,
          body: l10n.onboardingPage1Body,
        ),
        _OnboardPageData(
          icon: Icons.notifications_active_outlined,
          title: l10n.onboardingPage2Title,
          body: l10n.onboardingPage2Body,
        ),
        _OnboardPageData(
          icon: Icons.lock_outline,
          title: l10n.onboardingPage3Title,
          body: l10n.onboardingPage3Body,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = _pages(l10n);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardPage(data: pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: i == _page
                            ? AppTheme.primary
                            : AppTheme.surfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(96, 44),
                    ),
                    onPressed: () {
                      if (_page < pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      } else {
                        context.go('/notification-prompt');
                      }
                    },
                    child: Text(
                        _page < pages.length - 1 ? l10n.onboardingNext : l10n.onboardingStart),
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

class _OnboardPageData {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardPageData({required this.icon, required this.title, required this.body});
}

class _OnboardPage extends StatelessWidget {
  final _OnboardPageData data;
  const _OnboardPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 72, color: AppTheme.primary),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

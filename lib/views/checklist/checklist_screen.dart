import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/connected_app.dart';
import '../../models/submission_checklist_item.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/checklist_notifier.dart';
import '../../viewmodels/service_providers.dart';

/// 提出前チェックリスト（Should機能、設計書 v1.4新設）。
/// プライバシーポリシーURL有効性・年齢設定等、審査に落ちやすい頻出項目を提出前にセルフチェックする。
/// ①AIリジェクト診断[Could・事後対応]と対になる事前対応として位置づけ。
class ChecklistScreen extends ConsumerWidget {
  final ConnectedApp app;
  const ChecklistScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 永続化された進捗を一度だけ復元する（無ければ何もしない＝初期状態のまま）。
    ref.watch(checklistBootstrapProvider(app.id));
    final items = ref.watch(checklistProvider(app.id));
    final notifier = ref.read(checklistProvider(app.id).notifier);
    final checklistService = ref.read(checklistServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checklistTitle(app.displayName))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ProgressSummary(items: items),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return _ChecklistItemCard(
                  item: item,
                  label: checklistService.labelFor(l10n, item.itemKey),
                  onChanged: (result) =>
                      notifier.setResult(item.itemKey, result, DateTime.now()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  final List<SubmissionChecklistItem> items;
  const _ProgressSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final passCount = items
        .where((i) => i.result == ChecklistResult.pass)
        .length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : passCount / total;
    final allPassed = total > 0 && passCount == total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allPassed ? Icons.check_circle : Icons.rule,
                  color: allPassed ? AppTheme.primary : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Text(l10n.checklistProgress(passCount, total)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surfaceVariant,
              color: AppTheme.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              // 進捗バー自体は視覚的な塗り具合でしか割合を伝えないため、
              // スクリーンリーダー向けに明示的な値を持たせる(アクセシビリティ対応)。
              semanticsLabel: l10n.checklistProgress(passCount, total),
              semanticsValue: '${(progress * 100).round()}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final SubmissionChecklistItem item;
  final String label;
  final ValueChanged<ChecklistResult> onChanged;

  const _ChecklistItemCard({
    required this.item,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<ChecklistResult>(
              segments: [
                ButtonSegment(
                  value: ChecklistResult.unchecked,
                  label: Text(l10n.checklistResultUnchecked),
                  icon: const Icon(Icons.radio_button_unchecked, size: 16),
                ),
                ButtonSegment(
                  value: ChecklistResult.pass,
                  label: Text(l10n.checklistResultPass),
                  icon: const Icon(Icons.check, size: 16),
                ),
                ButtonSegment(
                  value: ChecklistResult.warning,
                  label: Text(l10n.checklistResultWarning),
                  icon: const Icon(Icons.priority_high, size: 16),
                ),
                ButtonSegment(
                  value: ChecklistResult.fail,
                  label: Text(l10n.checklistResultFail),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
              selected: {item.result},
              onSelectionChanged: (s) => onChanged(s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }
}

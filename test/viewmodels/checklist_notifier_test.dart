import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/submission_checklist_item.dart';
import 'package:ririkan/viewmodels/checklist_notifier.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('ChecklistNotifier', () {
    test('初期状態は固定マスタ全項目がuncheckedで生成される', () {
      final items = container.read(checklistProvider('app1'));
      expect(items.length, ChecklistItemKey.values.length);
      expect(items.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });

    test('setResultで該当項目のみ結果が更新される', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final checkedAt = DateTime(2026, 8, 5);
      notifier.setResult(
        ChecklistItemKey.privacyPolicyUrl,
        ChecklistResult.pass,
        checkedAt,
      );

      final items = container.read(checklistProvider('app1'));
      final target = items.firstWhere(
        (i) => i.itemKey == ChecklistItemKey.privacyPolicyUrl,
      );
      expect(target.result, ChecklistResult.pass);
      expect(target.checkedAt, checkedAt);

      final others = items.where(
        (i) => i.itemKey != ChecklistItemKey.privacyPolicyUrl,
      );
      expect(others.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });

    test('全項目passでallPassedがtrueになる', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final now = DateTime(2026, 8, 5);
      for (final key in ChecklistItemKey.values) {
        notifier.setResult(key, ChecklistResult.pass, now);
      }
      expect(notifier.allPassed, isTrue);
      expect(notifier.passCount, ChecklistItemKey.values.length);
    });

    test('1件でも未合格ならallPassedはfalse', () {
      final notifier = container.read(checklistProvider('app1').notifier);
      final now = DateTime(2026, 8, 5);
      for (final key in ChecklistItemKey.values) {
        notifier.setResult(key, ChecklistResult.pass, now);
      }
      notifier.setResult(
        ChecklistItemKey.values.first,
        ChecklistResult.fail,
        now,
      );
      expect(notifier.allPassed, isFalse);
    });

    test('別のconnectedAppIdは独立した状態を持つ', () {
      final notifierA = container.read(checklistProvider('appA').notifier);
      notifierA.setResult(
        ChecklistItemKey.ageRating,
        ChecklistResult.pass,
        DateTime(2026, 8, 5),
      );

      final itemsB = container.read(checklistProvider('appB'));
      expect(itemsB.every((i) => i.result == ChecklistResult.unchecked), isTrue);
    });
  });
}

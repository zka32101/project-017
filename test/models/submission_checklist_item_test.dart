import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/submission_checklist_item.dart';

void main() {
  group('SubmissionChecklistItem', () {
    test('toJson/fromJson が往復して同値になる', () {
      final item = SubmissionChecklistItem(
        id: 'app1_privacyPolicyUrl',
        connectedAppId: 'app1',
        itemKey: ChecklistItemKey.privacyPolicyUrl,
        checkedAt: DateTime(2026, 8, 5, 12, 30),
        result: ChecklistResult.pass,
      );
      final restored = SubmissionChecklistItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.connectedAppId, item.connectedAppId);
      expect(restored.itemKey, item.itemKey);
      expect(restored.checkedAt, item.checkedAt);
      expect(restored.result, item.result);
    });

    test('checkedAtがnullでも往復できる（未確認項目）', () {
      const item = SubmissionChecklistItem(
        id: 'app1_ageRating',
        connectedAppId: 'app1',
        itemKey: ChecklistItemKey.ageRating,
      );
      final restored = SubmissionChecklistItem.fromJson(item.toJson());

      expect(restored.checkedAt, isNull);
      expect(restored.result, ChecklistResult.unchecked);
    });

    test('result文字列が未知の値でもuncheckedにフォールバックする（フォーマット変更等への耐性）', () {
      final json = {
        'id': 'app1_ageRating',
        'connectedAppId': 'app1',
        'itemKey': ChecklistItemKey.ageRating.name,
        'checkedAt': null,
        'result': 'some_future_result_value',
      };
      final restored = SubmissionChecklistItem.fromJson(json);
      expect(restored.result, ChecklistResult.unchecked);
    });

    test('copyWithResultは指定フィールドのみ更新する', () {
      const item = SubmissionChecklistItem(
        id: 'app1_ageRating',
        connectedAppId: 'app1',
        itemKey: ChecklistItemKey.ageRating,
      );
      final checkedAt = DateTime(2026, 8, 5);
      final updated = item.copyWithResult(ChecklistResult.warning, checkedAt);

      expect(updated.result, ChecklistResult.warning);
      expect(updated.checkedAt, checkedAt);
      expect(updated.id, item.id);
      expect(updated.connectedAppId, item.connectedAppId);
      expect(updated.itemKey, item.itemKey);
    });
  });
}

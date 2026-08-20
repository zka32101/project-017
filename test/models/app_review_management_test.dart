import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/app_review_management.dart';
import 'package:ririkan/models/review_status_type.dart';

void main() {
  group('AppReviewManagement', () {
    test('empty()は全フィールドが未設定で、isEmptyはtrue', () {
      final management = AppReviewManagement.empty('app1');
      expect(management.manualStatusOverride, isNull);
      expect(management.submittedAt, isNull);
      expect(management.reviewStartedAt, isNull);
      expect(management.note, isEmpty);
      expect(management.isEmpty, isTrue);
    });

    test('いずれか1つでも値があればisEmptyはfalse', () {
      final management = AppReviewManagement(
        connectedAppId: 'app1',
        note: 'メモ',
      );
      expect(management.isEmpty, isFalse);
    });

    test('toJson/fromJson が往復して同値になる', () {
      final original = AppReviewManagement(
        connectedAppId: 'app1',
        manualStatusOverride: ReviewStatusType.rejected,
        submittedAt: DateTime(2026, 8, 1),
        reviewStartedAt: DateTime(2026, 8, 3),
        note: 'サポートへ問い合わせ中',
        updatedAt: DateTime(2026, 8, 5, 12, 30),
      );
      final restored = AppReviewManagement.fromJson(original.toJson());

      expect(restored.connectedAppId, original.connectedAppId);
      expect(restored.manualStatusOverride, original.manualStatusOverride);
      expect(restored.submittedAt, original.submittedAt);
      expect(restored.reviewStartedAt, original.reviewStartedAt);
      expect(restored.note, original.note);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('manualStatusOverride/日付/updatedAtがnullでも往復できる', () {
      final original = AppReviewManagement(connectedAppId: 'app1', note: 'x');
      final restored = AppReviewManagement.fromJson(original.toJson());

      expect(restored.manualStatusOverride, isNull);
      expect(restored.submittedAt, isNull);
      expect(restored.reviewStartedAt, isNull);
      expect(restored.updatedAt, isNull);
      expect(restored.note, 'x');
    });
  });
}

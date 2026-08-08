import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/review_status_snapshot.dart';
import 'package:ririkan/models/review_status_type.dart';

void main() {
  group('ReviewStatusSnapshot', () {
    test('toJson/fromJson が往復して同値になる', () {
      final snapshot = ReviewStatusSnapshot(
        id: 'snap1',
        connectedAppId: 'app1',
        versionString: '1.4.0',
        statusType: ReviewStatusType.inReview,
        fetchedAt: DateTime(2026, 8, 5, 9, 0),
      );
      final restored = ReviewStatusSnapshot.fromJson(snapshot.toJson());

      expect(restored.versionString, snapshot.versionString);
      expect(restored.statusType, snapshot.statusType);
      expect(restored.fetchedAt, snapshot.fetchedAt);
    });
  });

  group('ReviewStatusType.fromKey', () {
    test('既知のキーは対応するenumを返す', () {
      expect(ReviewStatusType.fromKey('rejected'), ReviewStatusType.rejected);
      expect(ReviewStatusType.fromKey('live'), ReviewStatusType.live);
    });

    test('未知のキーは waitingReview にフォールバックする', () {
      expect(ReviewStatusType.fromKey('unknown_key'),
          ReviewStatusType.waitingReview);
    });
  });
}

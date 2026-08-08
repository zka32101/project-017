import 'package:flutter_test/flutter_test.dart';
import 'package:ririkan/models/crash_summary.dart';

void main() {
  group('CrashSummary.isSpiking', () {
    test('閾値未満のクラッシュフリー率は急上昇と判定する', () {
      final summary = CrashSummary(
        id: 'c1',
        connectedAppId: 'app1',
        date: DateTime(2026, 8, 5),
        crashFreeRate: 97.0,
        crashCount: 40,
      );
      expect(summary.isSpiking(), isTrue);
    });

    test('閾値以上のクラッシュフリー率は正常と判定する', () {
      final summary = CrashSummary(
        id: 'c2',
        connectedAppId: 'app1',
        date: DateTime(2026, 8, 5),
        crashFreeRate: 99.8,
        crashCount: 1,
      );
      expect(summary.isSpiking(), isFalse);
    });

    test('カスタム閾値を指定できる', () {
      final summary = CrashSummary(
        id: 'c3',
        connectedAppId: 'app1',
        date: DateTime(2026, 8, 5),
        crashFreeRate: 99.5,
        crashCount: 3,
      );
      expect(summary.isSpiking(threshold: 99.9), isTrue);
      expect(summary.isSpiking(threshold: 99.0), isFalse);
    });
  });
}

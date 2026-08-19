import 'package:flutter/material.dart';

import '../models/review_status_type.dart';

/// 管制塔トーン（設計書 Step5.5）: 硬質・プロフェッショナル。教育アプリ系の可愛さとは対極。
/// ダークモード必須（開発者の利用環境を想定）。
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141A22);
  static const Color surfaceVariant = Color(0xFF1C2430);
  static const Color primary = Color(0xFF3DDC97); // 稼働中ランプ(緑)
  static const Color warning = Color(0xFFF5A623); // 審査中ランプ(琥珀)
  static const Color danger = Color(0xFFE5484D); // リジェクト/失敗ランプ(赤)
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B98A5);

  /// MaterialApp.router の theme/darkTheme 両方に同じ値を渡しているため
  /// (Step5.5 デザインでダークモード固定)、毎回 ThemeData.dark()+copyWith()を
  /// 再計算しないよう一度だけ計算してキャッシュする。
  static final ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: warning,
        error: danger,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(44), // 44pt+（設計書 Step5.5）
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceVariant),
        ),
      ),
    );
  }

  /// 審査状態→ランプ色（管制塔UIの中核メタファー）
  static Color colorForStatus(ReviewStatusType status) => switch (status) {
        ReviewStatusType.live || ReviewStatusType.approved => primary,
        ReviewStatusType.inReview || ReviewStatusType.waitingReview => warning,
        ReviewStatusType.rejected => danger,
      };
}

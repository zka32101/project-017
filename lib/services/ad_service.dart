import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// バナー広告（マネタイズ: 広告表示＋月$1で広告非表示）。
///
/// 【要設定】以下のテスト用広告ユニットIDはGoogle公式のデモ広告ID
/// (google_mobile_adsパッケージのexample同梱のものと同一)であり、実際の
/// 広告枠には紐づいていない。本番リリース前に、実際にAdMobで作成した
/// 広告ユニットIDへ置き換えること。テストIDのままでも動作はするが、
/// 収益は発生しない(常にGoogleのデモ広告が表示される)。
class AdService {
  const AdService();

  /// テスト用(Google公式デモ広告ID)。本番では実際の広告ユニットIDに置き換える。
  static String get bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-5058227312086483/6824611378'
      : 'ca-app-pub-5058227312086483/3359019401';

  /// main()で1回だけ呼ぶ（Widget buildからは呼ばない。flutter test環境では
  /// プラットフォームチャネル呼び出しで落ちるため、テストでは呼ばれないようにする）。
  Future<void> initialize() => MobileAds.instance.initialize();
}

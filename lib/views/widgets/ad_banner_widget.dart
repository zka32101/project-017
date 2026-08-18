import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ad_service.dart';

/// バナー広告表示Widget（無料ユーザー向け、マネタイズ）。
/// 読み込みが完了するまでは何も表示せず(レイアウトジャンプを避けるため
/// プレースホルダーの高さも確保しない、広告在庫が無い場合もあり得るため)、
/// 失敗時も静かに何も表示しない(ユーザー体験を壊さない)。
///
/// 実プラットフォームチャネルを叩くため、flutter test環境では直接使わないこと
/// (dashboard_screen.dart等の呼び出し元はadBannerWidgetBuilderProvider経由で
/// 参照し、テストではダミーのWidgetBuilderへ差し替える)。
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    final bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd = bannerAd;
    bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

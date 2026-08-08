/// アプリのプラットフォーム区分
enum PlatformType {
  ios,
  android;

  String get label => switch (this) {
        PlatformType.ios => 'iOS',
        PlatformType.android => 'Android',
      };
}

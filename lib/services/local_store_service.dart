import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/connected_app.dart';
import '../models/user_plan.dart';

/// 登録アプリ一覧・プランのローカル永続化（旧来はインメモリのみで、
/// アプリを再起動するたびに登録内容が消えていた）。
///
/// 保存するのは ConnectedApp のメタデータ（apiKeyRef は Secure Storage の
/// 参照キー文字列のみ）とプラン種別で、APIキー本体は含まない
/// （設計書 Step5 二重防御、Secure Storage側にのみ実体を保持する方針を維持）。
///
/// 読み書きはベストエフォート: path_provider のプラットフォームチャネルが
/// 使えない環境（単体テスト等）や、ディスクI/Oが失敗した場合でも例外を
/// 外に投げず null/no-op として振る舞う。呼び出し元はこれを「保存されて
/// いなかった」のと区別なく扱えるため、永続化層の不調がアプリの動作自体を
/// 止めることはない。
class LocalStoreService {
  const LocalStoreService();

  static const _fileName = 'ririkan_local_state.json';

  Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (_) {
      return null;
    }
  }

  Future<LocalState?> load() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LocalState.fromJson(json);
    } catch (_) {
      // 破損したJSON・未知のフォーマット等も含め、復元不能なら「保存データなし」
      // として扱う（初回起動時と同じフォールバック挙動＝デモアプリ投入に倒す）。
      return null;
    }
  }

  Future<void> save(LocalState state) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {
      // 永続化はベストエフォート。書き込み失敗はアプリの操作自体を妨げない
      // （registerApp/removeApp 等は Secure Storage への保存/削除さえ成功すれば
      // 完了として扱い、ローカルJSONへの反映失敗で例外を投げたりはしない）。
    }
  }
}

/// LocalStoreService が読み書きする内容。
class LocalState {
  final List<ConnectedApp> apps;
  final UserPlan plan;

  const LocalState({required this.apps, required this.plan});

  factory LocalState.fromJson(Map<String, dynamic> json) {
    final rawApps = json['apps'];
    final apps = <ConnectedApp>[];
    if (rawApps is List) {
      for (final entry in rawApps) {
        // 1件のフォーマット崩れ（未知のenum値・型不一致等）で復元処理全体を
        // 失敗させず、その1件だけ読み飛ばす。
        try {
          apps.add(ConnectedApp.fromJson(entry as Map<String, dynamic>));
        } catch (_) {
          continue;
        }
      }
    }

    final planName = json['plan'] as String?;
    final plan = UserPlan.values.firstWhere(
      (p) => p.name == planName,
      orElse: () => UserPlan.free,
    );

    return LocalState(apps: apps, plan: plan);
  }

  Map<String, dynamic> toJson() => {
        'apps': apps.map((a) => a.toJson()).toList(),
        'plan': plan.name,
      };
}

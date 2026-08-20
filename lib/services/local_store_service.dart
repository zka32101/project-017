import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_review_management.dart';
import '../models/connected_app.dart';
import '../models/submission_checklist_item.dart';
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

  /// 提出前チェックリストの進捗は connectedAppId ごとに独立した別ファイルに保存する
  /// （apps/planの共有ファイルに混ぜると、ConnectedAppsNotifierとChecklistNotifierが
  /// それぞれ非同期に保存する際、お互いの最新データを読み直さずに上書きし合う
  /// レースコンディションを持ち込むことになるため、あえて分離している）。
  ///
  /// connectedAppId はアプリ内部で uuid.v4() または固定のデモID文字列としてしか
  /// 生成されず、ファイル名として不正な文字を含み得るユーザー自由入力ではない
  /// （export_service.dart の displayName とは異なる）。
  Future<File?> _checklistFile(String connectedAppId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/ririkan_checklist_$connectedAppId.json');
    } catch (_) {
      return null;
    }
  }

  Future<List<SubmissionChecklistItem>?> loadChecklist(
    String connectedAppId,
  ) async {
    try {
      final file = await _checklistFile(connectedAppId);
      if (file == null || !await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final rawList = jsonDecode(raw);
      if (rawList is! List) return null;

      final items = <SubmissionChecklistItem>[];
      for (final entry in rawList) {
        // apps/planと同様、1件のフォーマット崩れで復元処理全体を失敗させない。
        try {
          items.add(
            SubmissionChecklistItem.fromJson(entry as Map<String, dynamic>),
          );
        } catch (_) {
          continue;
        }
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChecklist(
    String connectedAppId,
    List<SubmissionChecklistItem> items,
  ) async {
    try {
      final file = await _checklistFile(connectedAppId);
      if (file == null) return;
      await file.writeAsString(
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {
      // ベストエフォート。setResult()自体は失敗させない。
    }
  }

  /// アプリ削除時に呼ばれ、そのアプリのチェックリストファイルを消す
  /// （呼ばなくても実害は無いが、放置すると使われないファイルが残り続ける）。
  Future<void> deleteChecklist(String connectedAppId) async {
    try {
      final file = await _checklistFile(connectedAppId);
      if (file == null || !await file.exists()) return;
      await file.delete();
    } catch (_) {
      // ベストエフォート。removeApp()自体は失敗させない。
    }
  }

  /// 審査状態の手動上書き・提出日/審査開始日・メモ（AppReviewManagement）は
  /// チェックリストと同様、connectedAppIdごとに独立した別ファイルに保存する
  /// （理由は_checklistFile()のコメント参照、apps/planの共有ファイルへ混ぜると
  /// 非同期の複数箇所からの保存でレースコンディションが起きるため）。
  Future<File?> _managementFile(String connectedAppId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/ririkan_management_$connectedAppId.json');
    } catch (_) {
      return null;
    }
  }

  Future<AppReviewManagement?> loadManagement(String connectedAppId) async {
    try {
      final file = await _managementFile(connectedAppId);
      if (file == null || !await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppReviewManagement.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveManagement(
    String connectedAppId,
    AppReviewManagement info,
  ) async {
    try {
      final file = await _managementFile(connectedAppId);
      if (file == null) return;
      await file.writeAsString(jsonEncode(info.toJson()));
    } catch (_) {
      // ベストエフォート。
    }
  }

  /// アプリ削除時に呼ばれ、そのアプリの管理情報ファイルを消す。
  Future<void> deleteManagement(String connectedAppId) async {
    try {
      final file = await _managementFile(connectedAppId);
      if (file == null || !await file.exists()) return;
      await file.delete();
    } catch (_) {
      // ベストエフォート。removeApp()自体は失敗させない。
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

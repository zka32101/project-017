import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'local_store_service.dart';

/// Firebase Auth（匿名認証）+ Firestoreによる、ローカル永続化
/// （LocalStoreService）のクラウドバックアップ。
///
/// 【重要】これは複数端末間のリアルタイム同期ではない。ログイン画面を
/// 挟まない匿名認証は、UIDが「この端末のこのアプリインストール」に
/// 紐づく方式であり（FirebaseAuthのセッションはAndroidではアンインストールで
/// 消え、iOSでもKeychainがクリアされれば消える）、機種変更・再インストール
/// からの復元は保証しない。実際に助けになるのは「同じインストールのまま
/// ローカルJSONファイルだけが壊れた/消えた」場合の復旧に限られる
/// （複数端末間の同期やアプリ再インストール後の復元が必要になった場合は、
/// メール/Googleサインイン等の永続的な認証方式へ切り替える必要があるが、
/// 現状のスコープ外）。
abstract class CloudSyncService {
  /// main()で1回だけ呼ぶ。設定済みなら匿名認証でサインインする
  /// （既存セッションがあれば再利用し、毎回新しいUIDを発行しない。
  /// 新しいUIDになると過去のバックアップに二度とたどり着けなくなるため）。
  Future<void> initialize();

  /// 現在の状態をFirestoreへバックアップする。未設定・未サインイン・
  /// ネットワークエラー等、あらゆる失敗を内部で握りつぶし例外を投げない
  /// （ローカル永続化はこれとは独立して既に成功しているため、バックアップの
  /// 失敗でアプリの操作自体を妨げてはならない）。
  Future<void> backup(LocalState state);

  /// Firestoreにバックアップがあれば復元する。未設定・未サインイン・
  /// データ無し・エラー時はnull（呼び出し側はローカルに保存データが
  /// 無かった場合と同じ扱い＝デモアプリ投入にフォールバックする）。
  Future<LocalState?> restore();
}

class FirebaseCloudSyncService implements CloudSyncService {
  FirebaseCloudSyncService();

  /// 【要設定】Firebaseコンソール > プロジェクトの設定 >全般 から取得した値に
  /// 置き換えること（`flutterfire configure` を使う場合は生成された
  /// firebase_options.dart の DefaultFirebaseOptions の値をここへ転記してよい。
  /// projectId/messagingSenderIdはプラットフォーム共通、apiKey/appIdは
  /// プラットフォームごとに異なる）。
  /// プレースホルダのままの場合はinitialize()が実際の初期化をスキップし、
  /// 常に「クラウドバックアップ無し」状態のまま安全に動作する（クラッシュしない）。
  /// google-services.json/GoogleService-Info.plistの配置やGradle側の
  /// google-servicesプラグイン適用は不要（Firebase.initializeApp()に
  /// FirebaseOptionsを直接渡す「手動初期化」方式を採用しているため）。
  static const _iosApiKey = 'REPLACE_WITH_FIREBASE_IOS_API_KEY';
  static const _iosAppId = 'REPLACE_WITH_FIREBASE_IOS_APP_ID';
  static const _androidApiKey = 'REPLACE_WITH_FIREBASE_ANDROID_API_KEY';
  static const _androidAppId = 'REPLACE_WITH_FIREBASE_ANDROID_APP_ID';
  static const _messagingSenderId =
      'REPLACE_WITH_FIREBASE_MESSAGING_SENDER_ID';
  static const _projectId = 'REPLACE_WITH_FIREBASE_PROJECT_ID';

  /// Firestore側のコレクション名。1ユーザー(=匿名UID)につき1ドキュメント。
  /// セキュリティルールは firestore.rules を参照（request.auth.uid ==
  /// ドキュメントIDのユーザー本人のみ読み書き可能にする想定）。
  static const _collection = 'user_backups';

  // Purchases/Adsと同様、設定済みかどうかをstaticで保持する。main()で
  // initialize()したインスタンスと、cloudSyncServiceProvider経由で後から
  // 作られる別インスタンスとで状態が食い違わないようにするため。
  static bool _configured = false;

  static bool _isPlaceholder(String key) => key.startsWith('REPLACE_WITH_');

  @override
  Future<void> initialize() async {
    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    final appId = Platform.isIOS ? _iosAppId : _androidAppId;
    if (_isPlaceholder(apiKey) ||
        _isPlaceholder(appId) ||
        _isPlaceholder(_messagingSenderId) ||
        _isPlaceholder(_projectId)) {
      _configured = false;
      return;
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
      ),
    );

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    _configured = true;
  }

  /// _configuredかつサインイン済みの場合のみバックアップ先ドキュメントを返す。
  /// どちらかが欠けている場合はnull（呼び出し側はno-opとして扱う）。
  DocumentReference<Map<String, dynamic>>? get _docRef {
    if (!_configured) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection(_collection).doc(uid);
  }

  @override
  Future<void> backup(LocalState state) async {
    final ref = _docRef;
    if (ref == null) return;
    try {
      await ref.set(state.toJson());
    } catch (_) {
      // ベストエフォート。バックアップ失敗はローカル操作を妨げない
      // （呼び出し元のドキュメントコメント参照）。
    }
  }

  @override
  Future<LocalState?> restore() async {
    final ref = _docRef;
    if (ref == null) return null;
    try {
      final snapshot = await ref.get();
      final data = snapshot.data();
      if (data == null) return null;
      return LocalState.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

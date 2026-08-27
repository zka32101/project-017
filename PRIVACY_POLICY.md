# プライバシーポリシー / Privacy Policy

## 日本語版 / Japanese

### プライバシーポリシー

リリカン（以下「本アプリ」）のプライバシーポリシーをご説明します。

#### 1. 収集する情報

本アプリは以下の情報を収集します：

- **端末に保存されるデータ**
  - 登録されたアプリ情報（アプリ名、パッケージ名など）
  - APIキー・認証情報（ローカル暗号化保存）
  - ユーザーの設定・チェックリスト情報

- **ネットワーク通信時の情報**
  - App Store Connect API へのアクセス（iOS アプリ審査状況取得）
  - Google Play Developer API へのアクセス（Android アプリ審査状況取得）
  - クラウドバックアップ（Firebase Anonymous Auth）

#### 2. データの使用目的

- アプリレビュー状況の取得・表示
- ローカルデータバックアップ
- プッシュ通知機能の提供
- 広告表示（Google AdMob）

#### 3. データの共有

本アプリは、以下の場合を除きユーザーデータを第三者と共有しません：

- API 経由で App Store Connect / Google Play Developer API に送信するデータ
  （ユーザーが入力した認証情報・パッケージ名のみ）
- クラウドバックアップ用に Firebase に送信するデータ
  （匿名認証による端末固有ID）

#### 4. データセキュリティ

- APIキーはデバイスのセキュアストレージに暗号化されて保存されます
- クラウドバックアップは匿名認証（Anonymous Auth）を使用します
- Firebase Firestore へのアクセスはセキュリティルールで本人のみに制限されます

#### 5. データ削除

ユーザーはいつでも以下の方法でデータを削除できます：

- アプリ内の「設定」から「すべてのデータを削除」
- デバイスからアプリをアンインストール

---

## English

### Privacy Policy

This privacy policy explains how Ririkan (hereinafter "this app") handles your information.

#### 1. Information We Collect

This app collects the following information:

- **Data stored on your device**
  - Registered app information (app names, package names, etc.)
  - API keys and authentication credentials (encrypted local storage)
  - User settings and checklist progress

- **Data transmitted over the network**
  - App Store Connect API access (for iOS review status)
  - Google Play Developer API access (for Android review status)
  - Cloud backup (Firebase Anonymous Authentication)

#### 2. Purpose of Data Usage

- Retrieving and displaying app review statuses
- Local data backup
- Providing push notifications
- Displaying advertisements (Google AdMob)

#### 3. Data Sharing

This app does not share user data with third parties except in the following cases:

- Data transmitted via API to App Store Connect / Google Play Developer API
  (only authentication credentials and package names entered by the user)
- Data sent to Firebase for cloud backup
  (device-specific ID via anonymous authentication)

#### 4. Data Security

- API keys are encrypted and stored in your device's secure storage
- Cloud backup uses Anonymous Authentication
- Firebase Firestore access is restricted to the authenticated user by security rules

#### 5. Data Deletion

You can delete your data at any time by:

- Selecting "Delete All Data" from the app's Settings
- Uninstalling the app from your device

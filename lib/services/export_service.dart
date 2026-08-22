import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../models/build_failure_log.dart';
import '../models/connected_app.dart';
import '../models/export_job.dart';
import '../models/rejection_detail.dart';
import '../models/review_status_snapshot.dart';
import '../models/review_status_type.dart';

/// レポートエクスポート（Should機能、設計書 Step4）。
/// 本番設計はCloud Functionsトリガー→Cloud Storage署名付きURLだが、
/// Firebase未接続のMVP段階ではアプリ内でPDF/CSVを直接生成し、端末の一時ディレクトリに保存する。
/// 実サーバー接続時は generate() の内部実装のみ置き換えれば ExportJob の契約は変わらない。
class ExportService {
  const ExportService();

  /// PDF本文の日本語表示用フォント（Noto Sans JP, OFLライセンス）。
  /// pdfパッケージの既定フォントは日本語グリフを含まないため、明示的に埋め込む。
  static const _japaneseFontAsset = 'assets/fonts/NotoSansJP-Variable.ttf';

  /// ExportJob.expiresAt(export_screen.dartの「有効期限」表示)とpurgeExpiredExports()
  /// の削除しきい値を必ず同じ値にするための共有定数。以前はUI上「24時間で失効」と
  /// 表示するだけで実際のファイル削除が伴っておらず、端末内にエクスポート
  /// ファイルが無期限に蓄積し続けていた。
  static const expiryDuration = Duration(hours: 24);

  Future<ExportJob> generate({
    required String userId,
    required ConnectedApp app,
    required ExportFormat format,
    required List<ReviewStatusSnapshot> reviewHistory,
    required List<RejectionDetail> rejections,
    required List<BuildFailureLog> buildFailures,
    required DateTimeRange dateRange,
  }) async {
    final id = const Uuid().v4();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'ririkan_export_${sanitizeForFileName(app.displayName)}_${id.substring(0, 8)}.${format == ExportFormat.pdf ? 'pdf' : 'csv'}';
      final file = File('${dir.path}/$fileName');

      if (format == ExportFormat.csv) {
        final csv = buildCsv(app, reviewHistory, rejections, buildFailures);
        await file.writeAsString(csv);
      } else {
        final bytes = await buildPdf(
          app,
          reviewHistory,
          rejections,
          buildFailures,
        );
        await file.writeAsBytes(bytes);
      }

      // 署名付きURLは実サーバー実装時の値。MVPでは端末内ローカルパスをそのまま保持する
      // （24時間限定ダウンロードのexpiresAt契約のみ先取りで設定）。
      return ExportJob(
        id: id,
        userId: userId,
        connectedAppId: app.id,
        format: format,
        dateRange: dateRange,
        status: ExportJobStatus.ready,
        fileUrl: file.path,
        expiresAt: DateTime.now().add(expiryDuration),
      );
    } catch (e) {
      return ExportJob(
        id: id,
        userId: userId,
        connectedAppId: app.id,
        format: format,
        dateRange: dateRange,
        status: ExportJobStatus.failed,
      );
    }
  }

  /// 登録アプリ全件をまとめて1つのファイルへ出力する（全アプリ集約エクスポート）。
  /// generate()と同じ契約だが、ExportJob.connectedAppIdはnull(isAllApps=true)になる。
  Future<ExportJob> generateAll({
    required String userId,
    required List<AppExportBundle> bundles,
    required ExportFormat format,
    required DateTimeRange dateRange,
  }) async {
    final id = const Uuid().v4();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'ririkan_export_all_apps_${id.substring(0, 8)}.${format == ExportFormat.pdf ? 'pdf' : 'csv'}';
      final file = File('${dir.path}/$fileName');

      if (format == ExportFormat.csv) {
        final csv = buildCsvForAll(bundles);
        await file.writeAsString(csv);
      } else {
        final bytes = await buildPdfForAll(bundles);
        await file.writeAsBytes(bytes);
      }

      return ExportJob(
        id: id,
        userId: userId,
        // connectedAppId=null が「全アプリ集約」を表す(ExportJob.isAllApps参照)。
        format: format,
        dateRange: dateRange,
        status: ExportJobStatus.ready,
        fileUrl: file.path,
        expiresAt: DateTime.now().add(expiryDuration),
      );
    } catch (e) {
      return ExportJob(
        id: id,
        userId: userId,
        format: format,
        dateRange: dateRange,
        status: ExportJobStatus.failed,
      );
    }
  }

  /// エクスポートされるCSV/PDFのレポート本文は現状すべて日本語固定（多言語対応スコープ外、
  /// UI画面側の文言のみlib/l10n/*.arb経由でAppLocalizations化している）。
  /// ReviewStatusType.label はUI側でAppLocalizationsを渡す設計に変更したため
  /// （export_service.dartはBuildContextを持たない）、レポート専用に日本語固定のラベルを別途持つ。
  static String _reportLabelFor(ReviewStatusType status) => switch (status) {
    ReviewStatusType.waitingReview => '審査待ち',
    ReviewStatusType.inReview => '審査中',
    ReviewStatusType.rejected => 'リジェクト',
    ReviewStatusType.approved => '承認済み',
    ReviewStatusType.live => '公開中',
  };

  /// ファイル名に使うと壊れる文字（パス区切り、制御文字等）をアンダースコアに置換する。
  /// app.displayName はアプリ登録画面の自由入力のため、'/' や NUL 文字等を含み得る
  /// （例: 'Petit/Works App' → 'ririkan_export_Petit/Works App_xxx.pdf' という
  /// 存在しないサブディレクトリを指すパスになり、書き込みが必ず失敗していた）。
  /// buildCsv/buildPdf と同じ理由（ファイルI/Oを含まない）で公開し単体テスト可能にしている。
  static String sanitizeForFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? 'app' : sanitized;
  }

  /// generate()/generateAll()/exportAppRoster()が書き出したファイル
  /// (ririkan_export_*/ririkan_apps_*)のうち、作成からexpiryDuration
  /// (24時間)以上経過したものを削除する。以前はExportJob.expiresAtで
  /// 「24時間で失効」とUI表示するだけで実際の削除が伴っておらず、端末内に
  /// 無期限に蓄積し続けていた。main()から起動時に1回呼ぶ想定
  /// (失敗しても例外を投げないベストエフォート)。
  Future<void> purgeExpiredExports() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(expiryDuration);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('ririkan_export_') &&
            !name.startsWith('ririkan_apps_')) {
          continue;
        }
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // 1件の削除・stat失敗が他のファイルの掃除を止めないようにする。
        }
      }
    } catch (_) {
      // ベストエフォート。失敗してもアプリ起動自体は継続する。
    }
  }

  /// 「審査履歴/リジェクト理由/ビルド失敗ログ」の3セクション分の行を組み立てる
  /// (アプリ名の見出しは含まない)。単一アプリ用のbuildCsv・全アプリ集約用の
  /// buildCsvForAllの両方から共通で使う。
  List<List<dynamic>> _appSectionCsvRows(
    List<ReviewStatusSnapshot> reviewHistory,
    List<RejectionDetail> rejections,
    List<BuildFailureLog> buildFailures,
  ) => [
    ['審査履歴'],
    ['バージョン', '状態', '取得日時'],
    for (final s in reviewHistory)
      [
        s.versionString,
        _reportLabelFor(s.statusType),
        s.fetchedAt.toIso8601String(),
      ],
    [],
    ['リジェクト理由'],
    ['ガイドライン番号', 'タイトル', 'メッセージ', 'リジェクト日時'],
    for (final r in rejections)
      [
        r.guidelineNumber ?? '',
        r.guidelineTitle ?? '',
        r.resolutionCenterMessage,
        r.rejectedAt.toIso8601String(),
      ],
    [],
    ['ビルド失敗ログ'],
    ['ビルド番号', 'プラットフォーム', '失敗理由', '発生日時'],
    for (final b in buildFailures)
      [
        b.buildNumber,
        b.platform.label,
        b.failureReason,
        b.occurredAt.toIso8601String(),
      ],
  ];

  /// CSV生成ロジック本体（ファイルI/Oを含まないため単体テスト可能）。
  String buildCsv(
    ConnectedApp app,
    List<ReviewStatusSnapshot> reviewHistory,
    List<RejectionDetail> rejections,
    List<BuildFailureLog> buildFailures,
  ) {
    final rows = <List<dynamic>>[
      ['リリカン エクスポート: ${app.displayName}'],
      [],
      ..._appSectionCsvRows(reviewHistory, rejections, buildFailures),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// 全アプリ集約版のCSV生成ロジック本体（ファイルI/Oを含まないため単体テスト可能）。
  /// アプリごとに見出し行を挟みつつ、既存の3セクション構成をそのまま繰り返す。
  String buildCsvForAll(List<AppExportBundle> bundles) {
    final rows = <List<dynamic>>[
      ['リリカン エクスポート（全アプリ集約、${bundles.length}件）'],
      [],
      for (final b in bundles) ...[
        ['=== ${b.app.displayName} ==='],
        [],
        ..._appSectionCsvRows(b.reviewHistory, b.rejections, b.buildFailures),
        [],
      ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// 登録アプリ一覧そのもの（審査履歴等ではなく台帳データ）のCSV生成ロジック本体
  /// （ファイルI/Oを含まないため単体テスト可能）。大量アプリ管理の一環で、
  /// アプリ名・プラットフォーム・バンドルID/パッケージ名・タグを一覧化したい
  /// という要望に応える(buildCsv/buildCsvForAllは個別アプリの審査データが対象で、
  /// 台帳としては使えないため別メソッドとして分離している)。
  String buildAppRosterCsv(List<ConnectedApp> apps) {
    final rows = <List<dynamic>>[
      ['リリカン 登録アプリ一覧（${apps.length}件）'],
      [],
      ['表示名', 'プラットフォーム', 'バンドルID/パッケージ名', 'タグ'],
      for (final app in apps)
        [
          app.displayName,
          app.platform.label,
          app.bundleIdOrPackageName,
          app.tags.join(', '),
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// buildAppRosterCsv()の結果を端末内に書き出し、生成したファイルのパスを
  /// 返す(失敗時はnull)。generate()/generateAll()と異なりExportJobは介さない
  /// ―― 単発のCSVでdateRange/フォーマット選択/期限付きURLといった契約が
  /// 不要なため、戻り値をファイルパスの文字列だけに単純化している。
  Future<String?> exportAppRoster(List<ConnectedApp> apps) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'ririkan_apps_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buildAppRosterCsv(apps));
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 「審査履歴/リジェクト理由/ビルド失敗ログ」の3セクション分のWidgetを組み立てる
  /// (アプリ名の見出しは含まない)。単一アプリ用のbuildPdf・全アプリ集約用の
  /// buildPdfForAllの両方から共通で使う。
  List<pw.Widget> _appSectionPdfWidgets({
    required pw.TextStyle headerStyle,
    required pw.BoxDecoration headerDecoration,
    required List<ReviewStatusSnapshot> reviewHistory,
    required List<RejectionDetail> rejections,
    required List<BuildFailureLog> buildFailures,
  }) => [
    pw.Header(level: 1, text: '審査履歴'),
    pw.TableHelper.fromTextArray(
      headerStyle: headerStyle,
      headerDecoration: headerDecoration,
      headers: ['バージョン', '状態', '取得日時'],
      data: reviewHistory
          .map(
            (s) => [
              s.versionString,
              _reportLabelFor(s.statusType),
              s.fetchedAt.toIso8601String(),
            ],
          )
          .toList(),
    ),
    pw.SizedBox(height: 16),
    pw.Header(level: 1, text: 'リジェクト理由'),
    pw.TableHelper.fromTextArray(
      headerStyle: headerStyle,
      headerDecoration: headerDecoration,
      headers: ['ガイドライン', 'メッセージ', '日時'],
      data: rejections
          .map(
            (r) => [
              r.guidelineNumber ?? r.guidelineTitle ?? '-',
              r.resolutionCenterMessage,
              r.rejectedAt.toIso8601String(),
            ],
          )
          .toList(),
    ),
    pw.SizedBox(height: 16),
    pw.Header(level: 1, text: 'ビルド失敗ログ'),
    pw.TableHelper.fromTextArray(
      headerStyle: headerStyle,
      headerDecoration: headerDecoration,
      headers: ['ビルド番号', 'プラットフォーム', '失敗理由', '日時'],
      data: buildFailures
          .map(
            (b) => [
              b.buildNumber,
              b.platform.label,
              b.failureReason,
              b.occurredAt.toIso8601String(),
            ],
          )
          .toList(),
    ),
  ];

  /// pdfパッケージのpw.Document生成に必要な日本語フォント・共通スタイルを
  /// まとめて用意する(buildPdf/buildPdfForAll共通)。
  Future<
    ({
      pw.Document doc,
      pw.TextStyle headerStyle,
      pw.BoxDecoration headerDecoration,
    })
  >
  _preparePdfDocument() async {
    final fontData = await rootBundle.load(_japaneseFontAsset);
    final japaneseFont = pw.Font.ttf(fontData);

    // 注意: Noto Sans JPは可変フォント（1ファイルで全ウェイト内包）で、
    // このpdfパッケージのTTFパーサーはTrueType glyfアウトラインの既定インスタンスしか読めず
    // （fvar/gvarによる可変軸選択やCFF/OTFのBold単体ファイルには非対応）、既定が「Thin」になる。
    // そのため太字表現はフォントウェイトではなく、見出し用の背景色・サイズ・罫線で代替する。
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: japaneseFont, bold: japaneseFont),
    );
    final headerStyle = pw.TextStyle(
      font: japaneseFont,
      fontSize: 11,
      color: PdfColors.white,
    );
    const headerDecoration = pw.BoxDecoration(color: PdfColors.blueGrey700);
    return (
      doc: doc,
      headerStyle: headerStyle,
      headerDecoration: headerDecoration,
    );
  }

  /// PDF生成ロジック本体（ファイルI/Oを含まないため単体テスト可能）。
  Future<List<int>> buildPdf(
    ConnectedApp app,
    List<ReviewStatusSnapshot> reviewHistory,
    List<RejectionDetail> rejections,
    List<BuildFailureLog> buildFailures,
  ) async {
    final prepared = await _preparePdfDocument();
    prepared.doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'リリカン エクスポート: ${app.displayName}'),
          pw.SizedBox(height: 12),
          ..._appSectionPdfWidgets(
            headerStyle: prepared.headerStyle,
            headerDecoration: prepared.headerDecoration,
            reviewHistory: reviewHistory,
            rejections: rejections,
            buildFailures: buildFailures,
          ),
        ],
      ),
    );
    return prepared.doc.save();
  }

  /// 全アプリ集約版のPDF生成ロジック本体（ファイルI/Oを含まないため単体テスト可能）。
  /// アプリごとに見出し(Header level 1)を挟みつつ、既存の3セクション構成を繰り返す。
  Future<List<int>> buildPdfForAll(List<AppExportBundle> bundles) async {
    final prepared = await _preparePdfDocument();
    prepared.doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'リリカン エクスポート（全アプリ集約、${bundles.length}件）'),
          pw.SizedBox(height: 12),
          for (final b in bundles) ...[
            pw.Header(level: 0, text: b.app.displayName),
            ..._appSectionPdfWidgets(
              headerStyle: prepared.headerStyle,
              headerDecoration: prepared.headerDecoration,
              reviewHistory: b.reviewHistory,
              rejections: b.rejections,
              buildFailures: b.buildFailures,
            ),
            pw.SizedBox(height: 20),
          ],
        ],
      ),
    );
    return prepared.doc.save();
  }
}

/// 全アプリ集約エクスポート1件分の入力データ束。ExportServiceは各アプリの
/// 審査履歴/リジェクト理由/ビルド失敗ログをそれぞれ個別に取得する責務を
/// 持たない(Notifier層がProvider経由で集めてから渡す)ため、事前に集約済みの
/// データを1アプリ1インスタンスとして渡してもらう契約にしている。
class AppExportBundle {
  final ConnectedApp app;
  final List<ReviewStatusSnapshot> reviewHistory;
  final List<RejectionDetail> rejections;
  final List<BuildFailureLog> buildFailures;

  const AppExportBundle({
    required this.app,
    required this.reviewHistory,
    required this.rejections,
    required this.buildFailures,
  });
}

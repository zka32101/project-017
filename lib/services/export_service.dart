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

/// レポートエクスポート（Should機能、設計書 Step4）。
/// 本番設計はCloud Functionsトリガー→Cloud Storage署名付きURLだが、
/// Firebase未接続のMVP段階ではアプリ内でPDF/CSVを直接生成し、端末の一時ディレクトリに保存する。
/// 実サーバー接続時は generate() の内部実装のみ置き換えれば ExportJob の契約は変わらない。
class ExportService {
  const ExportService();

  /// PDF本文の日本語表示用フォント（Noto Sans JP, OFLライセンス）。
  /// pdfパッケージの既定フォントは日本語グリフを含まないため、明示的に埋め込む。
  static const _japaneseFontAsset = 'assets/fonts/NotoSansJP-Variable.ttf';

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
          'ririkan_export_${app.displayName}_${id.substring(0, 8)}.${format == ExportFormat.pdf ? 'pdf' : 'csv'}';
      final file = File('${dir.path}/$fileName');

      if (format == ExportFormat.csv) {
        final csv = buildCsv(app, reviewHistory, rejections, buildFailures);
        await file.writeAsString(csv);
      } else {
        final bytes =
            await buildPdf(app, reviewHistory, rejections, buildFailures);
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
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
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
      ['審査履歴'],
      ['バージョン', '状態', '取得日時'],
      for (final s in reviewHistory)
        [s.versionString, s.statusType.label, s.fetchedAt.toIso8601String()],
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
    return const ListToCsvConverter().convert(rows);
  }

  /// PDF生成ロジック本体（ファイルI/Oを含まないため単体テスト可能）。
  Future<List<int>> buildPdf(
    ConnectedApp app,
    List<ReviewStatusSnapshot> reviewHistory,
    List<RejectionDetail> rejections,
    List<BuildFailureLog> buildFailures,
  ) async {
    final fontData = await rootBundle.load(_japaneseFontAsset);
    final japaneseFont = pw.Font.ttf(fontData);

    // 注意: Noto Sans JPは可変フォント（1ファイルで全ウェイト内包）で、
    // このpdfパッケージのTTFパーサーはTrueType glyfアウトラインの既定インスタンスしか読めず
    // （fvar/gvarによる可変軸選択やCFF/OTFのBold単体ファイルには非対応）、既定が「Thin」になる。
    // そのため太字表現はフォントウェイトではなく、見出し用の背景色・サイズ・罫線で代替する。
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: japaneseFont,
        bold: japaneseFont,
      ),
    );
    final headerStyle = pw.TextStyle(
      font: japaneseFont,
      fontSize: 11,
      color: PdfColors.white,
    );
    final headerDecoration = const pw.BoxDecoration(color: PdfColors.blueGrey700);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'リリカン エクスポート: ${app.displayName}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, text: '審査履歴'),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            headers: ['バージョン', '状態', '取得日時'],
            data: reviewHistory
                .map((s) => [
                      s.versionString,
                      s.statusType.label,
                      s.fetchedAt.toIso8601String(),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'リジェクト理由'),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            headers: ['ガイドライン', 'メッセージ', '日時'],
            data: rejections
                .map((r) => [
                      r.guidelineNumber ?? r.guidelineTitle ?? '-',
                      r.resolutionCenterMessage,
                      r.rejectedAt.toIso8601String(),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'ビルド失敗ログ'),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            headers: ['ビルド番号', 'プラットフォーム', '失敗理由', '日時'],
            data: buildFailures
                .map((b) => [
                      b.buildNumber,
                      b.platform.label,
                      b.failureReason,
                      b.occurredAt.toIso8601String(),
                    ])
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }
}

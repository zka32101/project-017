package com.yourwish.ririkan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * リリカンのホーム画面ウィジェット（Should機能の土台）。
 * home_widgetパッケージがSharedPreferencesに書き込んだ値を読み出し、
 * 「要注意アプリ数」「登録アプリ数」を表示する。実際の値の同期はDart側の
 * WidgetSyncService.syncSummary() が担う（lib/services/widget_sync_service.dart）。
 */
class RirikanStatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val appCount = prefs.getInt("ririkan_app_count", 0)
        val attentionCount = prefs.getInt("ririkan_attention_count", 0)
        val latestSummary = prefs.getString("ririkan_latest_summary", "") ?: ""

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ririkan_status_widget)

            views.setTextViewText(
                R.id.widget_attention_count,
                attentionCount.toString(),
            )
            views.setTextViewText(
                R.id.widget_app_count,
                context.getString(R.string.widget_app_count_format, appCount),
            )
            views.setTextViewText(
                R.id.widget_latest_summary,
                if (latestSummary.isEmpty()) {
                    context.getString(R.string.widget_no_attention)
                } else {
                    latestSummary
                },
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

package xyz.krvishal.cimage_attendance

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

/**
 * Implementation of App Widget functionality.
 */
class AttendanceWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val views = RemoteViews(context.packageName, R.layout.attendance_widget)
    val widgetData = HomeWidgetPlugin.getData(context)
    val img = widgetData.getString("attendance_widget_image", null)
    if (img != null) {
        val imgFile = File(img)
        val imageExists = imgFile.exists()
        if (imageExists) {
            val myBitmap: Bitmap? = BitmapFactory.decodeFile(imgFile.absolutePath)
            myBitmap?.let {
                views.setImageViewBitmap(R.id.img_attendance, it)
            }
        }
    }
    appWidgetManager.updateAppWidget(appWidgetId, views)
}
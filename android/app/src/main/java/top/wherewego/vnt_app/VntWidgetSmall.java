package top.wherewego.vnt_app;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.widget.RemoteViews;

/**
 * VNT 小尺寸桌面小组件 (1x1)
 * 仅显示开关按钮
 */
public class VntWidgetSmall extends VntWidget {
    @Override
    protected RemoteViews getRemoteViews(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_small);
        updateSmallWidgetView(context, views);
        return views;
    }
}

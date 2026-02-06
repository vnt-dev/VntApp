package top.wherewego.vnt_app;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.widget.RemoteViews;

/**
 * VNT 大尺寸桌面小组件 (2x2)
 * 显示连接状态、设备数量、配置名称、开关按钮
 */
public class VntWidgetLarge extends VntWidget {
    @Override
    protected RemoteViews getRemoteViews(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_large);
        updateLargeWidgetView(context, views);
        return views;
    }
}

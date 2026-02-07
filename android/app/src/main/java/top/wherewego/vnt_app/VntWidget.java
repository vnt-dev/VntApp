package top.wherewego.vnt_app;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * VNT 桌面小组件基类
 * 提供通用的小组件功能
 */
public abstract class VntWidget extends AppWidgetProvider {
    private static final String TAG = "VntWidget";
    protected static final String ACTION_TOGGLE = "top.wherewego.vnt_app.WIDGET_TOGGLE";
    protected static final String PREFS_NAME = "FlutterSharedPreferences";
    protected static final String DATA_KEY_NATIVE = "flutter.data-key-native"; // 供原生代码读取的 JSON 格式
    protected static final String DEFAULT_KEY = "flutter.default-key";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.i(TAG, "onUpdate: 更新小组件");
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);

        if (ACTION_TOGGLE.equals(intent.getAction())) {
            Log.i(TAG, "收到切换连接状态的请求");
            handleToggle(context);
        }
    }

    /**
     * 子类实现此方法返回对应的 RemoteViews
     */
    protected abstract RemoteViews getRemoteViews(Context context, AppWidgetManager appWidgetManager, int appWidgetId);

    /**
     * 处理开关切换
     */
    private void handleToggle(Context context) {
        // 检查 Flutter 是否已初始化
        if (!FlutterMethodChannel.initialized()) {
            Log.i(TAG, "Flutter 未初始化，启动应用");
            // 启动应用并标记为从小组件启动
            FlutterMethodChannel.setTileStart(true);
            Intent intent = new Intent(context, MainActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return;
        }

        // 检查当前连接状态
        FlutterMethodChannel.isRunning(isRunning -> {
            if (isRunning) {
                Log.i(TAG, "当前已连接，立即更新UI为未连接状态，然后执行断开操作");
                // 立即更新UI为未连接状态
                updateAllWidgetsWithState(context, false);
                // 执行断开操作
                FlutterMethodChannel.stopVnt();
                // 更新通知栏状态
                VntNotificationService.updateNotification(context);
                // 更新磁贴状态
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    MyTileService.setState(false);
                }
            } else {
                Log.i(TAG, "当前未连接，立即更新UI为已连接状态，然后执行连接操作");
                // 立即更新UI为已连接状态
                updateAllWidgetsWithState(context, true);
                // 执行连接操作
                FlutterMethodChannel.startVnt(null, success -> {
                    Log.i(TAG, "连接结果: " + success);
                    // 根据实际连接结果更新UI状态
                    if (success) {
                        Log.i(TAG, "连接成功，确认UI为已连接状态");
                        updateAllWidgetsWithState(context, true);
                    } else {
                        Log.i(TAG, "连接失败，恢复UI为未连接状态");
                        updateAllWidgetsWithState(context, false);
                    }
                    // 更新通知栏状态
                    VntNotificationService.updateNotification(context);
                    // 更新磁贴状态
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        MyTileService.setState(success);
                    }
                    return null;
                });
            }
            return null;
        });
    }

    /**
     * 立即更新所有小组件为指定状态（用于乐观更新）
     */
    private static void updateAllWidgetsWithState(Context context, boolean isConnected) {
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);

        // 更新小尺寸小组件
        ComponentName smallComponent = new ComponentName(context, VntWidgetSmall.class);
        int[] smallWidgetIds = appWidgetManager.getAppWidgetIds(smallComponent);
        for (int appWidgetId : smallWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_small);
            if (isConnected) {
                views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_online);
                views.setTextViewText(R.id.widget_status, "已连接");
            } else {
                views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
                views.setTextViewText(R.id.widget_status, "未连接");
            }
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }

        // 更新大尺寸小组件
        ComponentName largeComponent = new ComponentName(context, VntWidgetLarge.class);
        int[] largeWidgetIds = appWidgetManager.getAppWidgetIds(largeComponent);
        for (int appWidgetId : largeWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_large);
            if (isConnected) {
                views.setTextViewText(R.id.widget_status, "已连接");
                views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_online);
                views.setTextViewText(R.id.widget_button, "断开");
                // 设置按钮背景为绿色（已连接状态）
                views.setInt(R.id.widget_button, "setBackgroundResource", R.drawable.widget_button_background);
            } else {
                views.setTextViewText(R.id.widget_status, "未连接");
                views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
                views.setTextViewText(R.id.widget_button, "连接");
                // 设置按钮背景为红色（未连接状态）
                views.setInt(R.id.widget_button, "setBackgroundResource", R.drawable.widget_button_background_connected);
            }
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }

    /**
     * 更新单个小组件
     */
    void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = getRemoteViews(context, appWidgetManager, appWidgetId);

        // 设置点击事件
        Intent toggleIntent = new Intent(context, this.getClass());
        toggleIntent.setAction(ACTION_TOGGLE);

        // 根据 Android 版本设置 PendingIntent flags
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            toggleIntent,
            flags
        );
        views.setOnClickPendingIntent(R.id.widget_button, pendingIntent);

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }

    /**
     * 更新小尺寸小组件
     */
    protected static void updateSmallWidgetView(Context context, RemoteViews views) {
        // 如果 Flutter 已初始化，获取实时连接状态
        if (FlutterMethodChannel.initialized()) {
            FlutterMethodChannel.isRunning(isConnected -> {
                // 设置按钮图标和文字
                if (isConnected) {
                    views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_online);
                    views.setTextViewText(R.id.widget_status, "已连接");
                } else {
                    views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
                    views.setTextViewText(R.id.widget_status, "未连接");
                }

                // 更新小组件
                AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
                ComponentName componentName = new ComponentName(context, VntWidgetSmall.class);
                int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);
                for (int appWidgetId : appWidgetIds) {
                    appWidgetManager.updateAppWidget(appWidgetId, views);
                }

                return null;
            });
        } else {
            // Flutter 未初始化，显示未连接状态
            views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
            views.setTextViewText(R.id.widget_status, "未连接");
        }
    }

    /**
     * 更新大尺寸小组件
     */
    protected static void updateLargeWidgetView(Context context, RemoteViews views) {
        // 如果 Flutter 已初始化，获取实时设备信息
        if (FlutterMethodChannel.initialized()) {
            FlutterMethodChannel.getDeviceInfo(deviceInfo -> {
                boolean isConnected = Boolean.TRUE.equals(deviceInfo.get("isConnected"));
                String configName = (String) deviceInfo.get("configName");
                int onlineCount = deviceInfo.get("onlineCount") != null ? (int) deviceInfo.get("onlineCount") : 0;
                int offlineCount = deviceInfo.get("offlineCount") != null ? (int) deviceInfo.get("offlineCount") : 0;

                if (configName == null || configName.isEmpty()) {
                    configName = "默认配置";
                }

                // 设置配置名称
                views.setTextViewText(R.id.widget_config_name, configName);

                // 设置连接状态
                if (isConnected) {
                    views.setTextViewText(R.id.widget_status, "已连接");
                    views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_online);
                    views.setTextViewText(R.id.widget_button, "断开");
                    // 设置按钮背景为绿色（已连接状态）
                    views.setInt(R.id.widget_button, "setBackgroundResource", R.drawable.widget_button_background);
                    // 设置设备数量
                    views.setTextViewText(R.id.widget_device_count, "在线: " + onlineCount + " | 离线: " + offlineCount);
                } else {
                    views.setTextViewText(R.id.widget_status, "未连接");
                    views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
                    views.setTextViewText(R.id.widget_button, "连接");
                    // 设置按钮背景为红色（未连接状态）
                    views.setInt(R.id.widget_button, "setBackgroundResource", R.drawable.widget_button_background_connected);
                    views.setTextViewText(R.id.widget_device_count, "点击连接");
                }

                // 更新小组件
                AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
                ComponentName componentName = new ComponentName(context, VntWidgetLarge.class);
                int[] appWidgetIds = appWidgetManager.getAppWidgetIds(componentName);
                for (int appWidgetId : appWidgetIds) {
                    appWidgetManager.updateAppWidget(appWidgetId, views);
                }

                return null;
            });
        } else {
            // Flutter 未初始化，读取配置信息
            String configName = "默认配置";
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String defaultKey = prefs.getString(DEFAULT_KEY, "");

            if (!defaultKey.isEmpty()) {
                try {
                    // 读取供原生代码使用的 JSON 格式配置列表
                    String jsonArrayStr = prefs.getString(DATA_KEY_NATIVE, null);
                    if (jsonArrayStr != null && !jsonArrayStr.isEmpty()) {
                        JSONArray jsonArray = new JSONArray(jsonArrayStr);
                        for (int i = 0; i < jsonArray.length(); i++) {
                            String configJsonStr = jsonArray.getString(i);
                            JSONObject configJson = new JSONObject(configJsonStr);
                            String key = configJson.optString("itemKey", "");
                            if (key.equals(defaultKey)) {
                                configName = configJson.optString("config_name", "未命名配置");
                                break;
                            }
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "读取配置失败", e);
                }
            }

            // 设置配置名称
            views.setTextViewText(R.id.widget_config_name, configName);
            views.setTextViewText(R.id.widget_status, "未连接");
            views.setImageViewResource(R.id.widget_icon, android.R.drawable.presence_offline);
            views.setTextViewText(R.id.widget_button, "连接");
            views.setTextViewText(R.id.widget_device_count, "点击连接");
        }
    }

    /**
     * 更新所有小组件
     */
    public static void updateAllWidgets(Context context) {
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);

        // 更新小尺寸小组件
        ComponentName smallComponent = new ComponentName(context, VntWidgetSmall.class);
        int[] smallWidgetIds = appWidgetManager.getAppWidgetIds(smallComponent);
        for (int appWidgetId : smallWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_small);
            updateSmallWidgetView(context, views);
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }

        // 更新大尺寸小组件
        ComponentName largeComponent = new ComponentName(context, VntWidgetLarge.class);
        int[] largeWidgetIds = appWidgetManager.getAppWidgetIds(largeComponent);
        for (int appWidgetId : largeWidgetIds) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_large);
            updateLargeWidgetView(context, views);
            appWidgetManager.updateAppWidget(appWidgetId, views);
        }
    }
}

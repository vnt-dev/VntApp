package top.wherewego.vnt_app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * VNT 常驻通知服务
 * 提供不可移除的常驻通知，显示连接状态并支持快速切换
 */
public class VntNotificationService extends Service {
    private static final String TAG = "VntNotificationService";
    private static final String CHANNEL_ID = "vnt_notification_channel";
    private static final int NOTIFICATION_ID = 1001;

    // 通知动作
    private static final String ACTION_TOGGLE = "top.wherewego.vnt_app.NOTIFICATION_TOGGLE";
    private static final String ACTION_UPDATE = "top.wherewego.vnt_app.NOTIFICATION_UPDATE";

    // SharedPreferences 相关
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String DATA_KEY_NATIVE = "flutter.data-key-native";
    private static final String DEFAULT_KEY = "flutter.default-key";

    private NotificationManager notificationManager;
    private NotificationReceiver notificationReceiver;
    private boolean isConnected = false;
    private String configName = "默认配置";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "VntNotificationService 创建");

        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        // 创建通知渠道（Android 8.0+）
        createNotificationChannel();

        // 注册广播接收器
        notificationReceiver = new NotificationReceiver();
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_TOGGLE);
        filter.addAction(ACTION_UPDATE);

        // 根据 Android 版本选择注册方式
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(notificationReceiver, filter);
        }

        // 读取配置名称
        loadConfigName();

        // 如果 Flutter 已初始化，从 Flutter 获取最新状态
        if (FlutterMethodChannel.initialized()) {
            updateNotificationFromFlutter();
        }

        // 启动前台服务
        startForeground(NOTIFICATION_ID, buildNotification());
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "VntNotificationService 启动");

        // 如果 Flutter 已初始化，获取当前连接状态
        if (FlutterMethodChannel.initialized()) {
            updateNotificationFromFlutter();
        }

        return START_STICKY; // 服务被杀死后自动重启
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.i(TAG, "VntNotificationService 销毁");

        // 注销广播接收器
        if (notificationReceiver != null) {
            unregisterReceiver(notificationReceiver);
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    /**
     * 创建通知渠道（Android 8.0+）
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "VNT 连接状态",
                NotificationManager.IMPORTANCE_LOW // 低重要性，不会发出声音
            );
            channel.setDescription("显示 VNT 连接状态和快速切换按钮");
            channel.setShowBadge(false); // 不显示角标
            channel.enableLights(false); // 不显示指示灯
            channel.enableVibration(false); // 不振动

            notificationManager.createNotificationChannel(channel);
        }
    }

    /**
     * 构建通知
     */
    private Notification buildNotification() {
        // 创建点击通知的 PendingIntent（打开应用）
        Intent notificationIntent = new Intent(this, MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);

        int pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingIntentFlags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent contentIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            pendingIntentFlags
        );

        // 创建切换按钮的 PendingIntent
        Intent toggleIntent = new Intent(ACTION_TOGGLE);
        PendingIntent togglePendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            toggleIntent,
            pendingIntentFlags
        );

        // 创建自定义通知布局
        RemoteViews notificationLayout = new RemoteViews(getPackageName(), R.layout.notification_layout);

        // 设置状态文本和颜色
        String statusText = isConnected ? "已连接" : "未连接";
        int statusColor = isConnected ? 0xFF4CAF50 : 0xFFF44336; // 绿色或红色
        notificationLayout.setTextViewText(R.id.notification_status, statusText);
        notificationLayout.setTextColor(R.id.notification_status, statusColor);

        // 设置说明文本
        String description = isConnected ? "已连接到 " + configName : "点击连接到 " + configName;
        notificationLayout.setTextViewText(R.id.notification_description, description);
        notificationLayout.setTextColor(R.id.notification_description, 0xFF1565C0); // 深蓝色

        // 设置按钮文本和背景
        String buttonText = isConnected ? "断开" : "连接";
        int buttonBackground = isConnected ? R.drawable.notification_button_connected : R.drawable.notification_button_disconnected;
        notificationLayout.setTextViewText(R.id.notification_button, buttonText);
        notificationLayout.setInt(R.id.notification_button, "setBackgroundResource", buttonBackground);

        // 设置按钮点击事件
        notificationLayout.setOnClickPendingIntent(R.id.notification_button, togglePendingIntent);

        // 构建通知
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_icon) // 状态栏图标（使用专门的通知图标）
            .setContentIntent(contentIntent)
            .setCustomContentView(notificationLayout) // 使用自定义布局
            .setStyle(new NotificationCompat.DecoratedCustomViewStyle()) // 使用装饰样式
            .setOngoing(true) // 设置为常驻通知，不可滑动删除
            .setPriority(NotificationCompat.PRIORITY_LOW) // 低优先级
            .setShowWhen(false) // 不显示时间
            .setAutoCancel(false); // 点击后不自动取消

        // Android 5.0+ 设置通知颜色（影响小图标）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setColor(statusColor);
        }

        return builder.build();
    }

    /**
     * 更新通知
     */
    private void updateNotification() {
        Notification notification = buildNotification();
        notificationManager.notify(NOTIFICATION_ID, notification);
        Log.i(TAG, "通知已更新: isConnected=" + isConnected + ", configName=" + configName);
    }

    /**
     * 从 Flutter 获取最新状态并更新通知
     */
    private void updateNotificationFromFlutter() {
        if (!FlutterMethodChannel.initialized()) {
            return;
        }

        FlutterMethodChannel.getDeviceInfo(deviceInfo -> {
            boolean newIsConnected = Boolean.TRUE.equals(deviceInfo.get("isConnected"));
            String newConfigName = (String) deviceInfo.get("configName");

            if (newConfigName == null || newConfigName.isEmpty()) {
                newConfigName = "默认配置";
            }

            // 更新状态
            isConnected = newIsConnected;
            configName = newConfigName;

            // 更新通知
            updateNotification();

            return null;
        });
    }

    /**
     * 从 SharedPreferences 加载配置名称
     */
    private void loadConfigName() {
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String defaultKey = prefs.getString(DEFAULT_KEY, "");

            if (!defaultKey.isEmpty()) {
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
            }
        } catch (Exception e) {
            Log.e(TAG, "加载配置名称失败", e);
            configName = "默认配置";
        }
    }

    /**
     * 处理切换连接状态
     */
    private void handleToggle() {
        Log.i(TAG, "收到切换连接状态的请求");

        // 检查 Flutter 是否已初始化
        if (!FlutterMethodChannel.initialized()) {
            Log.i(TAG, "Flutter 未初始化，启动应用");
            // 启动应用
            FlutterMethodChannel.setTileStart(true);
            Intent intent = new Intent(this, MainActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            return;
        }

        // 检查当前连接状态
        FlutterMethodChannel.isRunning(isRunning -> {
            if (isRunning) {
                Log.i(TAG, "当前已连接，立即更新通知为未连接状态，然后执行断开操作");
                // 立即更新通知为未连接状态（乐观更新）
                isConnected = false;
                updateNotification();
                // 执行断开操作
                FlutterMethodChannel.stopVnt();
                // 更新磁贴和小组件状态
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    MyTileService.setState(false);
                }
                VntWidget.updateAllWidgets(getApplicationContext());
            } else {
                Log.i(TAG, "当前未连接，立即更新通知为已连接状态，然后执行连接操作");
                // 立即更新通知为已连接状态（乐观更新）
                isConnected = true;
                updateNotification();
                // 执行连接操作
                FlutterMethodChannel.startVnt(null, success -> {
                    Log.i(TAG, "连接结果: " + success);
                    // 根据实际连接结果更新通知状态
                    if (success) {
                        Log.i(TAG, "连接成功，确认通知为已连接状态");
                        isConnected = true;
                        // 更新磁贴和小组件状态
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            MyTileService.setState(true);
                        }
                    } else {
                        Log.i(TAG, "连接失败，恢复通知为未连接状态");
                        isConnected = false;
                        // 更新磁贴和小组件状态
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            MyTileService.setState(false);
                        }
                    }
                    updateNotification();
                    VntWidget.updateAllWidgets(getApplicationContext());
                    return null;
                });
            }
            return null;
        });
    }

    /**
     * 广播接收器：处理通知动作
     */
    private class NotificationReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (ACTION_TOGGLE.equals(action)) {
                // 处理切换连接状态
                handleToggle();
            } else if (ACTION_UPDATE.equals(action)) {
                // 处理更新通知
                updateNotificationFromFlutter();
            }
        }
    }

    /**
     * 静态方法：更新通知状态（供外部调用）
     */
    public static void updateNotification(Context context) {
        Intent intent = new Intent(ACTION_UPDATE);
        context.sendBroadcast(intent);
    }
}

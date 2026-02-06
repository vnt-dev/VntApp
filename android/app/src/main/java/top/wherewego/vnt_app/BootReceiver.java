package top.wherewego.vnt_app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

/**
 * 开机自启接收器
 * 监听系统开机广播，根据设置自动启动应用
 */
public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String AUTO_START_KEY = "flutter.is-auto-start";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            Log.i(TAG, "收到开机广播");

            // 检查是否启用了开机自启
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            boolean autoStart = prefs.getBoolean(AUTO_START_KEY, false);

            if (autoStart) {
                Log.i(TAG, "开机自启已启用，准备启动应用");

                // 启动 MainActivity
                Intent launchIntent = new Intent(context, MainActivity.class);
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                launchIntent.putExtra("boot_start", true);

                try {
                    context.startActivity(launchIntent);
                    Log.i(TAG, "应用启动成功");
                } catch (Exception e) {
                    Log.e(TAG, "启动应用失败", e);
                }
            } else {
                Log.i(TAG, "开机自启未启用");
            }
        }
    }
}

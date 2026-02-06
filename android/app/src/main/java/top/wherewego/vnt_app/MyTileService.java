package top.wherewego.vnt_app;

import android.app.PendingIntent;
import android.content.Intent;
import android.os.Build;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.RequiresApi;

@RequiresApi(api = Build.VERSION_CODES.N)
public class MyTileService extends TileService {
    private static MyTileService self;

    public MyTileService() {
        self = this;
    }

    public static void setState(boolean isActive) {
        if (self == null) {
            return;
        }
        Tile tile = self.getQsTile();
        // 只更新磁贴显示状态，不触发连接操作
        if (isActive) {
            tile.setState(Tile.STATE_ACTIVE);
        } else {
            tile.setState(Tile.STATE_INACTIVE);
        }
        tile.setLabel("VNT");
        tile.updateTile();
    }

    @Override
    public void onTileAdded() {
        super.onTileAdded();
        Log.i("Tile", "onTileAdded");
    }

    @Override
    public void onStartListening() {
        super.onStartListening();
        FlutterMethodChannel.isRunning(isRunning -> {
            Tile tile = getQsTile();
            if (isRunning) {
                tile.setState(Tile.STATE_ACTIVE);
            } else {
                tile.setState(Tile.STATE_INACTIVE);
            }
            tile.setLabel("VNT");
            tile.updateTile();
            return null;
        });
        Log.i("Tile", "onStartListening");
    }

    @Override
    public void onStopListening() {
        super.onStopListening();
        // 停止监听状态变化时调用
        Log.i("Tile", "onStopListening");
    }

    @Override
    public void onTileRemoved() {
        super.onTileRemoved();
        // 磁贴从快速设置面板中移除时调用
        Log.i("Tile", "onTileRemoved");
    }

    @Override
    public void onClick() {
        super.onClick();
        // 当用户点击磁贴时调用
        Tile tile = getQsTile();
        Log.i("Tile", "onClick - 当前状态: " + (tile.getState() == Tile.STATE_INACTIVE ? "INACTIVE" : "ACTIVE"));
        Log.i("Tile", "Flutter 初始化状态: " + FlutterMethodChannel.initialized());

        if (tile.getState() == Tile.STATE_INACTIVE) {
            // 立即更新为激活状态，提供即时反馈
            tile.setState(Tile.STATE_ACTIVE);
            tile.updateTile();
            Log.i("Tile", "立即更新磁贴为激活状态");

            if (!FlutterMethodChannel.initialized()) {
                Log.i("Tile", "Flutter 未初始化，启动应用并标记为磁贴启动");
                //如果由磁贴启动，就自动连接
                FlutterMethodChannel.setTileStart(true);
                Intent intent = new Intent(this, MainActivity.class);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE));
                } else {
                    startActivityAndCollapse(intent);
                }
                return;
            }
            Log.i("Tile", "Flutter 已初始化，调用 startVnt");
            FlutterMethodChannel.startVnt(null, isRunning -> {
                Log.i("Tile", "startVnt 回调 - isRunning: " + isRunning);
                // 根据实际连接结果更新磁贴状态
                if (isRunning) {
                    tile.setState(Tile.STATE_ACTIVE);
                    Log.i("Tile", "连接成功，磁贴保持激活状态");
                } else {
                    tile.setState(Tile.STATE_INACTIVE);
                    Log.i("Tile", "连接失败，恢复磁贴为未激活状态");
                }
                tile.updateTile();
                // 更新通知栏状态
                VntNotificationService.updateNotification(getApplicationContext());
                // 更新小组件状态
                VntWidget.updateAllWidgets(getApplicationContext());
                return null;
            });
        } else {
            // 立即更新为未激活状态，提供即时反馈
            tile.setState(Tile.STATE_INACTIVE);
            tile.updateTile();
            Log.i("Tile", "立即更新磁贴为未激活状态");

            Log.i("Tile", "当前已连接，调用 stopVnt");
            FlutterMethodChannel.stopVnt();
            // 更新通知栏状态
            VntNotificationService.updateNotification(getApplicationContext());
            // 更新小组件状态
            VntWidget.updateAllWidgets(getApplicationContext());
        }
        Log.i("Tile", "onClick 完成");
    }
}


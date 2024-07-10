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
        if (isActive) {
            FlutterMethodChannel.startVnt(isRunning -> {
                if (isRunning) {
                    tile.setState(Tile.STATE_ACTIVE);
                } else {
                    tile.setState(Tile.STATE_INACTIVE);
                }
                tile.setLabel("VNT");
                tile.updateTile();
                return null;
            });
        } else {
            tile.setState(Tile.STATE_INACTIVE);
            tile.setLabel("VNT");
            tile.updateTile();
        }

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
        Log.i("Tile", "" + (tile.getState() == Tile.STATE_INACTIVE));
        if (tile.getState() == Tile.STATE_INACTIVE) {
            if (!FlutterMethodChannel.initialized()) {
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
            FlutterMethodChannel.startVnt(isRunning -> {
                if (isRunning) {
                    tile.setState(Tile.STATE_ACTIVE);
                } else {
                    tile.setState(Tile.STATE_INACTIVE);
                }
                tile.setLabel("VNT");
                tile.updateTile();
                return null;
            });
        } else {
            FlutterMethodChannel.stopVnt();
            tile.setState(Tile.STATE_INACTIVE);
            tile.setLabel("VNT");
            tile.updateTile();
        }
        Log.i("Tile", "onClick");
    }
}


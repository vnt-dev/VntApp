package top.wherewego.vnt_app;

import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import top.wherewego.vnt_app.vpn.DeviceConfig;
import top.wherewego.vnt_app.vpn.MyVpnService;

public class MainActivity extends FlutterActivity {
    private static final int VPN_REQUEST_CODE = 1;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        MyVpnService.stopVpn();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        FlutterMethodChannel.init(flutterEngine, new FlutterMethodChannel.Callback() {
            @Override
            public int startVpn(DeviceConfig config) {
                startVpnService(config);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    MyTileService.setState(true);
                }
                return 0;
            }

            @Override
            public void stopVpn() {
                MyVpnService.stopVpn();
            }

            @Override
            public void moveToBack() {
                moveTaskToBack(true);
            }
        });
    }



    private void startVpnService(DeviceConfig config) {
        MyVpnService.pendingConfig = config;
        Intent intent = VpnService.prepare(this);
        if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE);
        } else {
            onActivityResult(VPN_REQUEST_CODE, RESULT_OK, null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                Intent serviceIntent = new Intent(this, MyVpnService.class);
                startService(serviceIntent);
            } else {
                // 用户拒绝授权，返回错误结果给 Flutter
                FlutterMethodChannel.callError("User denied VPN authorization", null);
            }
        }
        super.onActivityResult(requestCode, resultCode, data);
    }
}

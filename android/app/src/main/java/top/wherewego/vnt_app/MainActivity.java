package top.wherewego.vnt_app;

import android.content.Intent;
import android.net.VpnService;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import top.wherewego.vnt_app.vpn.DeviceConfig;
import top.wherewego.vnt_app.vpn.IpUtils;
import top.wherewego.vnt_app.vpn.MyVpnService;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "top.wherewego.vnt/vpn";
    private static final int VPN_REQUEST_CODE = 1;
    private static final String TAG = "MainActivity";
    public static MethodChannel channel;

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
        channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler((call, result) -> {
            Log.i("moveTaskToBack","moveTaskToBack");
                    if (call.method.equals("startVpn")) {
                        try {
                            Map<String, Object> arguments = call.arguments();
                            DeviceConfig config = parseDeviceConfig(arguments);
                            startVpnService(config, result);
                        } catch (Exception e) {
                            result.error("VPN_ERROR", "Invalid DeviceConfig", e);
                        }
                    } else if (call.method.equals("stopVpn")) {
                        try {
                            MyVpnService.stopVpn();
                        } catch (Exception e) {
                            result.error("VPN_ERROR", "stopVpn", e);
                        }
                        result.success(null);
                    }else if (call.method.equals("moveTaskToBack")) {
                        // 将应用移至后台而不是退出应用
                        moveTaskToBack(true);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
        );

    }

    private DeviceConfig parseDeviceConfig(Map<String, Object> arguments) {
        String virtualIp = (String) arguments.get("virtualIp");
        String virtualNetmask = (String) arguments.get("virtualNetmask");
        String virtualGateway = (String) arguments.get("virtualGateway");
        Integer mtu = (Integer) arguments.get("mtu");

        List<Map<String, String>> externalRouteList = (List<Map<String, String>>) arguments.get("externalRoute");
        List<DeviceConfig.Route> externalRoute = new ArrayList<>();
        if (externalRouteList != null) {
            for (Map<String, String> route : externalRouteList) {
                String destination = route.get("destination");
                String netmask = route.get("netmask");
                externalRoute.add(new DeviceConfig.Route(IpUtils.ipToInt(destination), IpUtils.ipToInt(netmask)));
            }
        }
        return new DeviceConfig(IpUtils.ipToInt(virtualIp), IpUtils.ipToInt(virtualNetmask), IpUtils.ipToInt(virtualGateway), mtu, externalRoute);
    }

    private void startVpnService(DeviceConfig config, MethodChannel.Result result) {
        MyVpnService.pendingResult = result;
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
                MyVpnService.callError("User denied VPN authorization", null);
            }
        }
        super.onActivityResult(requestCode, resultCode, data);
    }
}

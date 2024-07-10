package top.wherewego.vnt_app.vpn;

import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.system.OsConstants;
import android.util.Log;

import java.io.IOException;

import io.flutter.plugin.common.MethodChannel;
import top.wherewego.vnt_app.FlutterMethodChannel;
import top.wherewego.vnt_app.MainActivity;
import top.wherewego.vnt_app.MyTileService;

public class MyVpnService extends VpnService {
    private static final String TAG = "MyVpnService";
    private static ParcelFileDescriptor vpnInterface;
    private volatile static MyVpnService vpnService;

    public static DeviceConfig pendingConfig;


    @Override
    public synchronized int onStartCommand(Intent intent, int flags, int startId) {
        vpnService = this;
        new Thread(() -> {
            try {
                int fd = startVpn(pendingConfig);
                FlutterMethodChannel.callSuccess(fd);
            } catch (Exception e) {
                Log.e(TAG, "pendingConfig =" + pendingConfig.toString(), e);
                FlutterMethodChannel.callError("Failed to start VPN", e);
            }
        }).start();
        return START_STICKY;
    }

    @Override
    public void onCreate() {
        // Listen for connectivity updates
        IntentFilter ifConnectivity = new IntentFilter();
        ifConnectivity.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
        super.onCreate();
    }

    public static void stopVpn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            MyTileService.setState(false);
        }
        FlutterMethodChannel.stopVnt();
        if (vpnService != null) {
            vpnService.stopSelf();
        }
        if (vpnInterface != null) {
            try {
                vpnInterface.close();
            } catch (IOException e) {
                Log.e(TAG, "Error closing existing VPN interface", e);
            }
        }
    }

    private int startVpn(DeviceConfig config) {
        Builder builder = new Builder();
        String ip = IpUtils.intToIpAddress(config.virtualIp);
        int prefixLength = IpUtils.subnetMaskToPrefixLength(config.virtualNetmask);
        String ipRoute = IpUtils.intToIpAddress(config.virtualGateway & config.virtualNetmask);
        builder
                .allowFamily(OsConstants.AF_INET)
                .setBlocking(false)
                .setMtu(config.mtu)
                .addAddress(ip, prefixLength)
                .addRoute(ipRoute, prefixLength);
        if (config.externalRoute != null) {
            for (DeviceConfig.Route routeItem : config.externalRoute) {
                int routePrefixLength = IpUtils.subnetMaskToPrefixLength(routeItem.netmask);
                String routeDest = IpUtils.intToIpAddress(routeItem.destination);
                builder.addRoute(routeDest, routePrefixLength);
            }
        }
        try {
            vpnInterface = builder.setSession("VNT")
                    .establish();
        } catch (Exception e) {
            Log.e(TAG, "Error establishing VPN interface", e);
        }
        return vpnInterface.getFd();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopVpn();
    }
}

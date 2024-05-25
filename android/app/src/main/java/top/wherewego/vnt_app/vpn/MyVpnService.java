package top.wherewego.vnt_app.vpn;

import android.net.VpnService;
import android.os.ParcelFileDescriptor;
import android.system.OsConstants;
import android.util.Log;

import java.io.IOException;

public class MyVpnService extends VpnService {
    private static final String TAG = "MyVpnService";
    private ParcelFileDescriptor vpnInterface;

    public int startVpn(DeviceConfig config) {
        if (vpnInterface != null) {
            try {
                vpnInterface.close();
            } catch (IOException e) {
                Log.e(TAG, "Error closing existing VPN interface", e);
            }
        }

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

                builder.addAddress(routeDest, routePrefixLength);
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
        if (vpnInterface != null) {
            try {
                vpnInterface.close();
            } catch (IOException e) {
                Log.e(TAG, "Error closing VPN interface", e);
            }
        }
    }
}

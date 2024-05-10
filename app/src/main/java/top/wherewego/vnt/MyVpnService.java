package top.wherewego.vnt;

import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.system.OsConstants;
import android.util.Log;
import android.widget.Toast;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.List;

import top.wherewego.vnt.config.ConfigurationInfoBean;
import top.wherewego.vnt.jni.CallBack;
import top.wherewego.vnt.jni.Config;
import top.wherewego.vnt.jni.DeviceBean;
import top.wherewego.vnt.jni.IpUtils;
import top.wherewego.vnt.jni.PeerRouteInfo;
import top.wherewego.vnt.jni.Vnt;
import top.wherewego.vnt.jni.param.ConnectInfo;
import top.wherewego.vnt.jni.param.DeviceConfig;
import top.wherewego.vnt.jni.param.DeviceInfo;
import top.wherewego.vnt.jni.param.ErrorInfo;
import top.wherewego.vnt.jni.param.HandshakeInfo;
import top.wherewego.vnt.jni.param.PeerClientInfo;
import top.wherewego.vnt.jni.param.RegisterInfo;
import top.wherewego.vnt.util.IpRouteUtils;

public class MyVpnService extends VpnService implements Runnable {
    private static MyVpnService myVpnService;
    private Thread mThread;
    private ParcelFileDescriptor mInterface;
    private Vnt eVnt;
    private Config config;

    public static PeerRouteInfo[] peerList() {
        if (myVpnService != null && myVpnService.eVnt != null) {
            return myVpnService.eVnt.list();
        }
        return new PeerRouteInfo[0];
    }

    public static boolean isStart() {
        return myVpnService != null && myVpnService.mThread != null;
    }

    public static void stop() {
        if (myVpnService != null) {
            myVpnService.stop0();
        }
    }

    @Override
    public void onCreate() {
        myVpnService = this;
        // Listen for connectivity updates
        IntentFilter ifConnectivity = new IntentFilter();
        ifConnectivity.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
        super.onCreate();
    }

    @Override
    public synchronized int onStartCommand(Intent intent, int flags, int startId) {
        switch (intent.getAction()) {
            case "start": {
                config = (ConfigurationInfoBean) intent.getSerializableExtra("config");
                if (mThread == null) {
                    mThread = new Thread(this, "VntVPN");
                    mThread.start();
                }
                break;
            }
            case "stop": {
                stop0();
                break;
            }
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stop0();
    }

    @Override
    public void run() {
        try {
            run0();
        } catch (Throwable e) {
            Handler handler = new Handler(Looper.getMainLooper());
            handler.post(() -> Toast.makeText(getApplicationContext(), "启动失败:" + e.getMessage(), Toast.LENGTH_LONG).show());
        }
        Handler handler = new Handler(Looper.getMainLooper());
        handler.post(() -> {
            Toast.makeText(getApplicationContext(), "Vnt已停止", Toast.LENGTH_LONG).show();
        });
        stop0();
        eVnt = null;
        mInterface = null;
        mThread = null;
    }

    private synchronized void stop0() {
        if (eVnt != null) {
            eVnt.stop();
        }
        if (myVpnService != null) {
            myVpnService.stopSelf();

        }
        if (mInterface != null) {
            try {
                mInterface.close();
            } catch (IOException e) {
                Log.e("mInterface", "mInterface", e);
            }
        }
    }

    private void run0() {
        try {

            eVnt = new Vnt(config, new CallBack() {
                @Override
                public void success() {

                }

                @Override
                public void createTun(DeviceInfo info) {

                }

                @Override
                public void connect(ConnectInfo info) {

                }

                @Override
                public boolean handshake(HandshakeInfo info) {
                    return true;
                }

                @Override
                public boolean register(RegisterInfo info) {
                    Handler handler = new Handler(Looper.getMainLooper());
                    handler.post(() -> Toast.makeText(getApplicationContext(), "注册成功", Toast.LENGTH_SHORT).show());
                    return true;
                }

                @Override
                public int generateTun(DeviceConfig info) throws PackageManager.NameNotFoundException {
                    String ip = IpUtils.intToIpAddress(info.getVirtualIp());
                    {
                        Handler handler = new Handler(Looper.getMainLooper());
                        handler.post(() -> {
                            ConnectActivity.headerView.setText("Token:" + config.getToken()
                                    + "\nName:" + config.getName()
                                    + "\nServer:" + config.getServer()
                                    + "\nIp:" + ip);
                        });
                    }

                    Builder builder = new Builder();
                    int prefixLength = IpUtils.subnetMaskToPrefixLength(info.getVirtualNetmask());
                    String ipRoute = IpUtils.intToIpAddress(info.getVirtualGateway() & info.getVirtualNetmask());
                    List<IpRouteUtils.RouteItem> routeItems = IpRouteUtils.inIp(String.join("\n", info.getExternalRoute()));
                    builder.setSession("VntVPN")
                            //.addDisallowedApplication("top.wherewego.vnt")
                            .setBlocking(false)
                            .setMtu(1410)
                            .addAddress(ip, prefixLength)
                            .addRoute(ipRoute, prefixLength);
                    for (IpRouteUtils.RouteItem routeItem : routeItems) {
                        builder.addAddress(routeItem.address, routeItem.prefixLength);
                    }
                    builder.allowFamily(OsConstants.AF_INET);
                    mInterface = builder.establish();
                    return mInterface.getFd();
                }

                @Override
                public void peerClientList(PeerClientInfo[] infoArray) {

                }

                @Override
                public void error(ErrorInfo info) {
                    Handler handler = new Handler(Looper.getMainLooper());
                    handler.post(() -> Toast.makeText(getApplicationContext(), "启动失败：" + info.toString(), Toast.LENGTH_SHORT).show());
                }

                @Override
                public void stop() {
                    Handler handler = new Handler(Looper.getMainLooper());
                    handler.post(() -> Toast.makeText(getApplicationContext(), "vnt服务停止", Toast.LENGTH_SHORT).show());
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
            Log.i("vnt", "vnt ", e);
            Handler handler = new Handler(Looper.getMainLooper());
            handler.post(() -> Toast.makeText(getApplicationContext(), "启动失败：" + e.getMessage(), Toast.LENGTH_SHORT).show());
            return;
        }

        Handler handler = new Handler(Looper.getMainLooper());
        for (; ; ) {
            handler.post(() -> {
                List<DeviceBean> list = new ArrayList<>();
                PeerRouteInfo[] peerRouteInfos = eVnt.list();
                if (peerRouteInfos != null) {
                    for (PeerRouteInfo peer : peerRouteInfos) {
                        String rt = "";
                        String type = "";
                        if (peer.getRoute() != null) {
                            rt = "" + peer.getRoute().getRt();
                            type = peer.getRoute().getMetric() == 1 ? "p2p" : "relay";
                        }
                        DeviceBean deviceBean = new DeviceBean(peer.getName(), IpUtils.intToIpAddress(peer.getVirtualIp()),
                                peer.getStatus(), rt, type);
                        list.add(deviceBean);
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        list.sort(DeviceBean::compareTo);
                    }
                    ConnectActivity.mAdapter.setData(list);
                }

            });
            boolean out = eVnt.awaitTimeout(2000);
            if (out) {
                break;
            }
        }

    }
}

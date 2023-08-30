package top.wherewego.vnt;

import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.system.OsConstants;
import android.widget.Toast;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.List;

import top.wherewego.vnt.jni.Config;
import top.wherewego.vnt.jni.DeviceBean;
import top.wherewego.vnt.jni.IpUtils;
import top.wherewego.vnt.jni.PeerDeviceInfo;
import top.wherewego.vnt.jni.RegResponse;
import top.wherewego.vnt.jni.Vnt;
import top.wherewego.vnt.jni.VntUtil;
import top.wherewego.vnt.jni.exception.AddressExhaustedException;
import top.wherewego.vnt.jni.exception.TimeoutException;
import top.wherewego.vnt.jni.exception.TokenErrorException;

public class MyVpnService extends VpnService implements Runnable {
    private static MyVpnService myVpnService;
    private Thread mThread;
    private ParcelFileDescriptor mInterface;
    private Vnt eVnt;
    private Config config;
    private volatile boolean isRun;

    public static PeerDeviceInfo[] peerList() {
        if (myVpnService != null && myVpnService.eVnt != null) {
            return myVpnService.eVnt.list();
        }
        return new PeerDeviceInfo[0];
    }

    public static boolean isStart() {
        return myVpnService != null && myVpnService.mThread != null;
    }

    public static void stop() {
        if (myVpnService != null) {
            myVpnService.stopSelf();
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
                isRun = true;
                String token = intent.getStringExtra("token");
                String deviceId = intent.getStringExtra("deviceId");
                String name = intent.getStringExtra("name");
                String password = intent.getStringExtra("password");
                String server = intent.getStringExtra("server");
                String stunServer = intent.getStringExtra("stunServer");
                String cipherModel = intent.getStringExtra("cipherModel");
                boolean isTcp = intent.getBooleanExtra("isTcp", false);
                config = new Config(token, name, deviceId, server, stunServer, password.isEmpty() ? null : password, cipherModel, isTcp);
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
            handler.post(() -> Toast.makeText(getApplicationContext(), "启动失败", Toast.LENGTH_LONG).show());
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
        isRun = false;
        if (eVnt != null) {
            eVnt.stop();
        }
        try {
            if (mInterface != null) {
                mInterface.close();
            }
        } catch (IOException ignored) {
        }
        if (mThread != null) {
            mThread.interrupt();
        }
    }

    private void run0() {
        try {
            String[] parts = config.getServer().split(":");
            new InetSocketAddress(parts[0], Integer.parseInt(parts[1]));
        } catch (Exception ignored) {
            Handler handler = new Handler(Looper.getMainLooper());
            handler.post(() -> Toast.makeText(getApplicationContext(), "ServerAddress error", Toast.LENGTH_SHORT).show());
            return;
        }
        VntUtil vntUtil = new VntUtil(config);
        RegResponse connect;
        for (; ; ) {
            if (!isRun) {
                return;
            }
            try {
                vntUtil.connect();
                connect = vntUtil.register();
                break;
            } catch (AddressExhaustedException e) {
                Handler handler = new Handler(Looper.getMainLooper());
                handler.post(() -> Toast.makeText(getApplicationContext(), "Address Exhausted", Toast.LENGTH_SHORT).show());
                return;
            } catch (TimeoutException e) {
                Handler handler = new Handler(Looper.getMainLooper());
                handler.post(() -> Toast.makeText(getApplicationContext(), "Connect Timeout", Toast.LENGTH_SHORT).show());
                try {
                    Thread.sleep(3000);
                } catch (InterruptedException ignored) {
                }
            } catch (TokenErrorException e) {
                Handler handler = new Handler(Looper.getMainLooper());
                handler.post(() -> Toast.makeText(getApplicationContext(), "Token Error", Toast.LENGTH_SHORT).show());
                return;
            }
        }
        String ip = IpUtils.intToIpAddress(connect.getVirtualIp());
//        String gateway = IpUtils.intToIpAddress(connect.getVirtualGateway());
//        String netmask = IpUtils.intToIpAddress(connect.getVirtualNetmask());
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
        int prefixLength = IpUtils.subnetMaskToPrefixLength(connect.getVirtualNetmask());
        String ipRoute = IpUtils.intToIpAddress(connect.getVirtualGateway() & connect.getVirtualNetmask());
        builder.setSession("VntVPN")
                .setBlocking(true)
                .setMtu(1420)
                .addAddress(ip, prefixLength)
//                    .addDnsServer("8.8.8.8")
                .addRoute(ipRoute, prefixLength);
        builder.allowFamily(OsConstants.AF_INET);
        mInterface = builder.establish();
        int fd = mInterface.getFd();
        vntUtil.createIface(fd);
        Vnt eVntC = vntUtil.build();
        eVnt = eVntC;
        Handler handler = new Handler(Looper.getMainLooper());
        for (; ; ) {
            handler.post(() -> {
                List<DeviceBean> list = new ArrayList<>();
                for (PeerDeviceInfo peer : eVnt.list()) {
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
            });
            boolean out = eVntC.waitStopMs(2000);
            if (out) {
                break;
            }
        }

    }
}

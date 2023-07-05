package top.wherewego.switchapp;

import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.system.OsConstants;
import android.widget.Toast;

import java.io.IOException;
import java.net.InetSocketAddress;

import top.wherewego.switchjni.Config;
import top.wherewego.switchjni.IpUtils;
import top.wherewego.switchjni.PeerDeviceInfo;
import top.wherewego.switchjni.RegResponse;
import top.wherewego.switchjni.Switch;
import top.wherewego.switchjni.SwitchUtil;
import top.wherewego.switchjni.exception.AddressExhaustedException;
import top.wherewego.switchjni.exception.TimeoutException;
import top.wherewego.switchjni.exception.TokenErrorException;

public class MyVpnService extends VpnService implements Runnable {
    private static MyVpnService myVpnService;
    private Thread mThread;
    private ParcelFileDescriptor mInterface;
    private Switch eSwitch;
    private Config config;

    public static PeerDeviceInfo[] peerList() {
        if (myVpnService != null && myVpnService.eSwitch != null) {
            return myVpnService.eSwitch.list();
        }
        return new PeerDeviceInfo[0];
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
                String token = intent.getStringExtra("token");
                String deviceId = intent.getStringExtra("deviceId");
                String name = intent.getStringExtra("name");
                String server = intent.getStringExtra("server");
                String natServer = intent.getStringExtra("natServer");
                config = new Config(token, deviceId, name, server, natServer);
                if (mThread == null) {
                    mThread = new Thread(this, "SwitchVPN");
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
            handler.post(() -> Toast.makeText(getApplicationContext(), "Switch Startup failed", Toast.LENGTH_LONG).show());
        }
        Handler handler = new Handler(Looper.getMainLooper());
        handler.post(() -> {
            Toast.makeText(getApplicationContext(), "Switch Stopped", Toast.LENGTH_LONG).show();
        });
        stop0();
        eSwitch = null;
        mInterface = null;
        mThread = null;
    }

    private void stop0() {
        if (eSwitch != null) {
            eSwitch.stop();
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
        SwitchUtil switchUtil = new SwitchUtil(config);
        RegResponse connect;
        for (; ; ) {
            try {
                connect = switchUtil.connect();
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
//        {
//            Handler handler = new Handler(Looper.getMainLooper());
//            handler.post(() -> MainActivity.textViewHint.setText("Start Successfully" +
//                    "\nVirtual Gateway: " + gateway
//                    + "\nVirtual Ip: " + ip
//                    + "\nVirtual Netmask: " + netmask));
//        }

        Builder builder = new Builder();
        int prefixLength = IpUtils.subnetMaskToPrefixLength(connect.getVirtualNetmask());
        String ipRoute = IpUtils.intToIpAddress(connect.getVirtualGateway() & connect.getVirtualNetmask());
        builder.setSession("SwitchVPN")
                .setBlocking(true)
                .setMtu(1420)
                .addAddress(ip, prefixLength)
//                    .addDnsServer("8.8.8.8")
                .addRoute(ipRoute, prefixLength);
        builder.allowFamily(OsConstants.AF_INET);
        mInterface = builder.establish();
        int fd = mInterface.getFd();
        switchUtil.createIface(fd);
        Switch eSwitchC = switchUtil.build();
        eSwitch = eSwitchC;
        eSwitchC.waitStop();
    }
}

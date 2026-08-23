package com.rustvnt.vntapp;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import com.vnt.RegisterResult;
import com.vnt.VntApi;
import com.vnt.VntManager;
import com.vnt.VntNetwork;
import org.json.JSONArray;
import org.json.JSONObject;
import java.lang.ref.WeakReference;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

public final class VntVpnService extends VpnService {
    static final String ACTION_STATE = "com.rustvnt.vntapp.STATE";
    private static final String ACTION_START = "com.rustvnt.vntapp.START";
    private static final String ACTION_STOP = "com.rustvnt.vntapp.STOP";
    private static final String CHANNEL_ID = "vnt_connection";
    private static final int NOTIFICATION_ID = 1207;
    private static final String ACTIVE_PREFS = "vnt_active_connection";

    private static volatile VntState state = VntState.stopped();
    private static volatile boolean uiVisible;
    private static volatile WeakReference<VntVpnService> instance = new WeakReference<>(null);
    private ScheduledExecutorService worker;
    private ScheduledFuture<?> refreshTask;
    private VntNetwork network;
    private VntApi api;
    private ParcelFileDescriptor vpnInterface;
    private final Map<String, VntApi.Traffic> trafficSamples = new HashMap<>();
    private long trafficSampleTime;
    private volatile boolean cancellationRequested;

    static VntState state() { return state; }

    static void setUiVisible(boolean visible) {
        uiVisible = visible;
        VntVpnService service = instance.get();
        if (service == null || service.worker == null || service.worker.isShutdown()) return;
        try {
            service.worker.execute(() -> {
                if (visible) {
                    service.refresh();
                    service.startRefreshing();
                } else {
                    service.stopRefreshing();
                }
            });
        } catch (RejectedExecutionException ignored) { }
    }

    static void start(Context context, VntConfigStore.Profile profile) {
        Intent intent = new Intent(context, VntVpnService.class)
                .setAction(ACTION_START)
                .putExtra("id", profile.id)
                .putExtra("name", profile.name)
                .putExtra("json", profile.json);
        ContextCompat.startForegroundService(context, intent);
    }

    static void stop(Context context) {
        context.startService(new Intent(context, VntVpnService.class).setAction(ACTION_STOP));
    }

    @Override public void onCreate() {
        super.onCreate();
        instance = new WeakReference<>(this);
        createNotificationChannel();
        worker = Executors.newSingleThreadScheduledExecutor();
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? null : intent.getAction();
        if (intent == null) {
            SharedPreferences active = getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE);
            String json = active.getString("json", null);
            if (json != null && network == null) {
                String id = active.getString("id", "");
                String name = active.getString("name", "VNT");
                startForeground(NOTIFICATION_ID, notification("正在恢复虚拟网络…", false));
                worker.execute(() -> connect(id, name, json));
            }
            return START_STICKY;
        }
        if (ACTION_STOP.equals(action)) {
            cancellationRequested = true;
            publish(new VntState(VntState.Status.STOPPING, state.profileId, state.profileName,
                    state.ip, "正在停止，请稍候…", null, null, null, null, null));
            worker.execute(this::shutdown);
            return START_NOT_STICKY;
        }
        if (ACTION_START.equals(action)) {
            String id = intent.getStringExtra("id");
            String name = intent.getStringExtra("name");
            String json = intent.getStringExtra("json");
            cancellationRequested = false;
            getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit()
                    .putString("id", id).putString("name", name).putString("json", json).apply();
            startForeground(NOTIFICATION_ID, notification("正在建立虚拟网络…", false));
            worker.execute(() -> connect(id, name, json));
        }
        return START_STICKY;
    }

    private void connect(String id, String name, String json) {
        cleanupNative();
        publish(new VntState(VntState.Status.STARTING, id, name, null,
                "正在连接服务器并注册网络…", null, null, null, null, null));
        try {
            if (!VntManager.init()) throw new IllegalStateException("Rust 核心初始化失败");
            network = VntManager.createNetwork(json);
            if (network == null) throw new IllegalStateException("Rust 核心无法创建网络实例");
            RegisterResult registration = network.register();
            if (cancellationRequested) { shutdown(); return; }

            if (!network.isNoTun()) {
                JSONObject config = new JSONObject(json);
                int mtu = Math.max(576, Math.min(9000, config.optInt("mtu", 1380)));
                Builder builder = new Builder()
                        .setSession("VNT · " + name)
                        .setMtu(mtu)
                        .addAddress(registration.getIp(), registration.getPrefixLen());
                // Native control/P2P sockets run under this UID and must bypass the VPN route.
                builder.addDisallowedApplication(getPackageName());
                addRoute(builder, networkAddress(registration.getIp(), registration.getPrefixLen()), registration.getPrefixLen());
                JSONArray output = config.optJSONArray("output");
                Set<String> seen = new HashSet<>();
                seen.add(networkAddress(registration.getIp(), registration.getPrefixLen()) + "/" + registration.getPrefixLen());
                if (output != null) {
                    for (int i = 0; i < output.length(); i++) {
                        String cidr = output.optString(i).trim();
                        if (cidr.isEmpty() || !seen.add(cidr)) continue;
                        String[] parts = cidr.split("/");
                        if (parts.length == 2) addRoute(builder, parts[0], Integer.parseInt(parts[1]));
                    }
                }
                // 入栈网段格式为 "网段,目标IP"，需要把网段本身捕获进 VPN 接口，核心才能转发到目标节点
                JSONArray input = config.optJSONArray("input");
                if (input != null) {
                    for (int i = 0; i < input.length(); i++) {
                        String cidr = input.optString(i).split(",")[0].trim();
                        if (cidr.isEmpty() || !seen.add(cidr)) continue;
                        String[] parts = cidr.split("/");
                        if (parts.length == 2) addRoute(builder, parts[0], Integer.parseInt(parts[1]));
                    }
                }
                vpnInterface = builder.establish();
                if (vpnInterface == null) throw new IllegalStateException("Android 未能建立 VPN 接口");
                // Transfer fd ownership to tun-rs. Keeping a Java owner as well would
                // allow both runtimes to close the same descriptor during shutdown.
                int tunFd = vpnInterface.detachFd();
                vpnInterface = null;
                network.startTun(tunFd);
            }

            api = network.getApi();
            if (cancellationRequested) { shutdown(); return; }
            VntState running = readState(id, name, registration.getIp());
            publish(running);
            startForeground(NOTIFICATION_ID, notification("已连接 · " + registration.getIp(), true));
            startRefreshing();
        } catch (Throwable error) {
            if (cancellationRequested) { shutdown(); return; }
            cleanupNative();
            clearActiveConnection();
            String message = rootMessage(error);
            publish(new VntState(VntState.Status.ERROR, id, name, null,
                    "连接失败：" + message, null, null, null, null, null));
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
        }
    }

    private void refresh() {
        VntState current = state;
        if (!uiVisible || current.status != VntState.Status.RUNNING || api == null) return;
        try { publish(readState(current.profileId, current.profileName, current.ip)); }
        catch (Throwable ignored) { }
    }

    private void startRefreshing() {
        if (!uiVisible || api == null || state.status != VntState.Status.RUNNING) return;
        if (refreshTask == null || refreshTask.isCancelled() || refreshTask.isDone()) {
            refreshTask = worker.scheduleWithFixedDelay(this::refresh, 3, 3, TimeUnit.SECONDS);
        }
    }

    private void stopRefreshing() {
        if (refreshTask != null) {
            refreshTask.cancel(false);
            refreshTask = null;
        }
        resetTrafficSamples();
    }

    private VntState readState(String id, String name, String ip) throws Exception {
        List<VntApi.ClientInfo> clients = withTrafficSpeeds(api.getClientList());
        List<VntApi.ServerInfo> servers = api.getServerList();
        List<VntApi.RouteInfo> routes = api.getRouteTable();
        VntApi.NatInfo nat = api.getNatInfo();
        VntApi.NetworkInfo network = api.getNetwork();
        return new VntState(VntState.Status.RUNNING, id, name, ip,
                "", clients, servers, routes, nat, network);
    }

    private synchronized List<VntApi.ClientInfo> withTrafficSpeeds(List<VntApi.ClientInfo> clients) {
        long now = SystemClock.elapsedRealtime();
        long elapsed = trafficSampleTime == 0 ? 0 : now - trafficSampleTime;
        Map<String, VntApi.Traffic> nextSamples = new HashMap<>();
        List<VntApi.ClientInfo> result = new ArrayList<>(clients.size());
        for (VntApi.ClientInfo client : clients) {
            VntApi.Traffic traffic = client.traffic();
            VntApi.Traffic measured = null;
            if (traffic != null) {
                VntApi.Traffic previous = trafficSamples.get(client.ip());
                long txSpeed = previous == null || elapsed <= 0 ? 0 : bytesPerSecond(
                        traffic.txBytes(), previous.txBytes(), elapsed);
                long rxSpeed = previous == null || elapsed <= 0 ? 0 : bytesPerSecond(
                        traffic.rxBytes(), previous.rxBytes(), elapsed);
                measured = new VntApi.Traffic(
                        traffic.txBytes(), traffic.rxBytes(), txSpeed, rxSpeed);
                nextSamples.put(client.ip(), measured);
            }
            result.add(new VntApi.ClientInfo(
                    client.ip(), client.name(), client.version(), client.online(), client.direct(),
                    client.routeProtocol(), client.routeMetric(), client.rtt(), client.keyEqual(),
                    client.loss(), measured));
        }
        trafficSamples.clear();
        trafficSamples.putAll(nextSamples);
        trafficSampleTime = now;
        return result;
    }

    private static long bytesPerSecond(long current, long previous, long elapsedMillis) {
        long difference = Math.max(0, current - previous);
        return Math.round(difference * 1000d / elapsedMillis);
    }

    private synchronized void resetTrafficSamples() {
        trafficSamples.clear();
        trafficSampleTime = 0;
    }

    private void shutdown() {
        cleanupNative();
        clearActiveConnection();
        publish(VntState.stopped());
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void cleanupNative() {
        stopRefreshing();
        api = null;
        if (network != null) {
            try { network.stop(); } catch (Throwable ignored) { }
            network = null;
        }
        if (vpnInterface != null) {
            try { vpnInterface.close(); } catch (Exception ignored) { }
            vpnInterface = null;
        }
        try { VntManager.destroy(); } catch (Throwable ignored) { }
    }

    private void publish(VntState next) {
        state = next;
        sendBroadcast(new Intent(ACTION_STATE).setPackage(getPackageName()));
    }

    private void clearActiveConnection() {
        getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit().clear().apply();
    }

    private Notification notification(String text, boolean connected) {
        Intent open = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingOpen = PendingIntent.getActivity(this, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        PendingIntent pendingStop = PendingIntent.getService(this, 1,
                new Intent(this, VntVpnService.class).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_warning)
                .setContentTitle(connected ? "VNT 虚拟网络已连接" : "VNT 正在启动")
                .setContentText(text)
                .setContentIntent(pendingOpen)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .addAction(0, "停止", pendingStop)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "VNT 连接状态",
                    NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("保持 VNT 虚拟网络在后台运行");
            getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    private static void addRoute(Builder builder, String address, int prefix) {
        if (prefix < 0 || prefix > 32) throw new IllegalArgumentException("无效路由前缀：" + prefix);
        builder.addRoute(address, prefix);
    }

    private static String networkAddress(String ip, int prefix) throws Exception {
        byte[] bytes = InetAddress.getByName(ip).getAddress();
        int value = ((bytes[0] & 255) << 24) | ((bytes[1] & 255) << 16) |
                ((bytes[2] & 255) << 8) | (bytes[3] & 255);
        int mask = prefix == 0 ? 0 : -1 << (32 - prefix);
        int network = value & mask;
        return ((network >>> 24) & 255) + "." + ((network >>> 16) & 255) + "." +
                ((network >>> 8) & 255) + "." + (network & 255);
    }

    private static String rootMessage(Throwable error) {
        Throwable cursor = error;
        while (cursor.getCause() != null) cursor = cursor.getCause();
        String message = cursor.getMessage();
        return message == null || message.isBlank() ? cursor.getClass().getSimpleName() : message;
    }

    @Override public void onRevoke() { shutdown(); }

    @Override public void onDestroy() {
        cleanupNative();
        if (instance.get() == this) instance.clear();
        if (worker != null) worker.shutdownNow();
        super.onDestroy();
    }
}

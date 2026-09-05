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
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
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
    private final IpUpdateQueue ipUpdates = new IpUpdateQueue();
    private final SubnetRouteUpdateQueue subnetRouteUpdates = new SubnetRouteUpdateQueue();
    private String activeProfileName;
    private String activeConfigJson;
    private boolean activeAllowIkev2;
    private String activeIp;
    private int activePrefixLen;
    private List<String> activeSubnetRoutes = Collections.emptyList();
    private Set<String> appliedSubnetRouteCidrs = Collections.emptySet();
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
                    state.ip, "正在停止，请稍候…", state.allowIkev2,
                    null, null, null, null, null));
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
        ipUpdates.reset();
        subnetRouteUpdates.reset();
        activeProfileName = name;
        activeConfigJson = json;
        try {
            JSONObject config = new JSONObject(json);
            activeSubnetRoutes = arrayStrings(config.optJSONArray("input"));
            activeAllowIkev2 = config.optBoolean("allow_ikev2", false);
        } catch (Exception ignored) {
            activeSubnetRoutes = Collections.emptyList();
            activeAllowIkev2 = false;
        }
        publish(new VntState(VntState.Status.STARTING, id, name, null,
                "正在连接服务器并注册网络…", activeAllowIkev2,
                null, null, null, null, null));
        try {
            if (!VntManager.init()) throw new IllegalStateException("Rust 核心初始化失败");
            network = VntManager.createNetwork(json, new VntNetwork.IpUpdateListener() {
                @Override public void onIpUpdate(long requestId, String ip, int prefixLen) {
                    VntVpnService.this.onIpUpdate(requestId, ip, prefixLen);
                }

                @Override public void onSubnetRoutesChanged(String routesJson) {
                    VntVpnService.this.onSubnetRoutesChanged(routesJson);
                }
            });
            if (network == null) throw new IllegalStateException("Rust 核心无法创建网络实例");
            RegisterResult registration = network.register();
            if (cancellationRequested) { shutdown(); return; }
            activeIp = registration.getIp();
            activePrefixLen = registration.getPrefixLen();

            if (!network.isNoTun()) {
                vpnInterface = establishVpn(name, json, registration.getIp(), registration.getPrefixLen());
                if (vpnInterface == null) throw new IllegalStateException("Android 未能建立 VPN 接口");
                // Transfer fd ownership to tun-rs. Keeping a Java owner as well would
                // allow both runtimes to close the same descriptor during shutdown.
                int tunFd = vpnInterface.detachFd();
                vpnInterface = null;
                network.startTun(tunFd);
                appliedSubnetRouteCidrs = VpnRouteSet.cidrs(activeSubnetRoutes);
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
                    "连接失败：" + message, activeAllowIkev2,
                    null, null, null, null, null));
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

    private ParcelFileDescriptor establishVpn(String name, String json, String ip, int prefixLen) throws Exception {
        JSONObject config = new JSONObject(json);
        int mtu = Math.max(576, Math.min(9000, config.optInt("mtu", 1380)));
        Builder builder = new Builder()
                .setSession("VNT · " + name)
                .setMtu(mtu)
                .addAddress(ip, prefixLen);
        builder.addDisallowedApplication(getPackageName());
        for (VpnRouteSet.Route route : VpnRouteSet.build(ip, prefixLen,
                arrayStrings(config.optJSONArray("output")),
                arrayStrings(config.optJSONArray("input")), activeSubnetRoutes)) {
            addRoute(builder, route.address(), route.prefix());
        }
        return builder.establish();
    }

    private void onIpUpdate(long requestId, String ip, int prefixLen) {
        if (cancellationRequested || worker == null || worker.isShutdown()) return;
        if (!ipUpdates.offer(new IpUpdateQueue.Request(requestId, ip, prefixLen))) return;
        try {
            worker.execute(this::drainIpUpdates);
        } catch (RejectedExecutionException ignored) { }
    }

    private void onSubnetRoutesChanged(String routesJson) {
        if (cancellationRequested || worker == null || worker.isShutdown()) return;
        if (!subnetRouteUpdates.offer(routesJson)) return;
        try {
            worker.execute(this::drainSubnetRouteUpdates);
        } catch (RejectedExecutionException ignored) { }
    }

    private void drainIpUpdates() {
        IpUpdateQueue.Request request;
        while (!cancellationRequested && (request = ipUpdates.take()) != null) {
            try {
                applyIpUpdate(request);
            } catch (Throwable error) {
                failIpUpdate(error);
                return;
            }
        }
    }

    private void applyIpUpdate(IpUpdateQueue.Request request) throws Exception {
        VntNetwork activeNetwork = network;
        if (activeNetwork == null || state.status != VntState.Status.RUNNING) return;

        IpUpdateSequence.run(activeNetwork.isNoTun(), new IpUpdateSequence.Operations() {
            @Override public void prepare() throws Exception {
                // 返回前 Rust 已停止读写任务并关闭旧 fd；之后才能建立新 VPN。
                activeNetwork.prepareIpUpdate(request.requestId(), request.ip());
            }

            @Override public int establish() throws Exception {
                ParcelFileDescriptor replacement = establishVpn(
                        activeProfileName, activeConfigJson, request.ip(), request.prefixLen());
                if (replacement == null) {
                    throw new IllegalStateException("Android 未能建立新的 VPN 接口");
                }
                return replacement.detachFd();
            }

            @Override public void complete(int tunFd) throws Exception {
                activeNetwork.completeIpUpdate(request.requestId(), request.ip(), tunFd);
            }
        });

        VntState running = readState(state.profileId, state.profileName, request.ip());
        activeIp = request.ip();
        activePrefixLen = request.prefixLen();
        appliedSubnetRouteCidrs = VpnRouteSet.cidrs(activeSubnetRoutes);
        publish(running);
        startForeground(NOTIFICATION_ID, notification("已连接 · " + request.ip(), true));
    }

    private void drainSubnetRouteUpdates() {
        String routesJson;
        while (!cancellationRequested && (routesJson = subnetRouteUpdates.take()) != null) {
            try {
                applySubnetRouteUpdate(routesJson);
            } catch (Throwable error) {
                failSubnetRouteUpdate(error);
                return;
            }
        }
    }

    private void applySubnetRouteUpdate(String routesJson) throws Exception {
        VntNetwork activeNetwork = network;
        if (activeNetwork == null || state.status != VntState.Status.RUNNING) return;

        List<String> routes = arrayStrings(new JSONArray(routesJson));
        Set<String> desiredCidrs = VpnRouteSet.cidrs(routes);
        activeSubnetRoutes = Collections.unmodifiableList(new ArrayList<>(routes));
        if (activeNetwork.isNoTun() || desiredCidrs.equals(appliedSubnetRouteCidrs)) return;

        RouteUpdateSequence.run(new RouteUpdateSequence.Operations() {
            @Override public void prepare() throws Exception {
                activeNetwork.prepareRouteUpdate();
            }

            @Override public int establish() throws Exception {
                ParcelFileDescriptor replacement = establishVpn(
                        activeProfileName, activeConfigJson, activeIp, activePrefixLen);
                if (replacement == null) {
                    throw new IllegalStateException("Android 未能建立包含同步路由的新 VPN 接口");
                }
                return replacement.detachFd();
            }

            @Override public void complete(int tunFd) throws Exception {
                activeNetwork.completeRouteUpdate(tunFd);
            }
        });
        appliedSubnetRouteCidrs = desiredCidrs;
    }

    private void failSubnetRouteUpdate(Throwable error) {
        cancellationRequested = true;
        subnetRouteUpdates.close();
        String profileId = state.profileId;
        String profileName = state.profileName;
        cleanupNative();
        clearActiveConnection();
        publish(new VntState(VntState.Status.ERROR, profileId, profileName, null,
                "更新自动同步路由失败：" + rootMessage(error), activeAllowIkev2,
                null, null, null, null, null));
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
    }

    private void failIpUpdate(Throwable error) {
        cancellationRequested = true;
        ipUpdates.close();
        String profileId = state.profileId;
        String profileName = state.profileName;
        cleanupNative();
        clearActiveConnection();
        publish(new VntState(VntState.Status.ERROR, profileId, profileName, null,
                "更新虚拟 IP 失败：" + rootMessage(error), activeAllowIkev2,
                null, null, null, null, null));
        stopForeground(STOP_FOREGROUND_REMOVE);
        stopSelf();
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
                "", activeAllowIkev2, clients, servers, routes, nat, network);
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
                    client.ip(), client.name(), client.version(), client.clientType(), client.online(), client.direct(),
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
        ipUpdates.close();
        subnetRouteUpdates.close();
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
        activeProfileName = null;
        activeConfigJson = null;
        activeAllowIkev2 = false;
        activeIp = null;
        activePrefixLen = 0;
        activeSubnetRoutes = Collections.emptyList();
        appliedSubnetRouteCidrs = Collections.emptySet();
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

    private static List<String> arrayStrings(JSONArray array) {
        if (array == null) return Collections.emptyList();
        List<String> result = new ArrayList<>(array.length());
        for (int i = 0; i < array.length(); i++) {
            String value = array.optString(i).trim();
            if (!value.isEmpty()) result.add(value);
        }
        return result;
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

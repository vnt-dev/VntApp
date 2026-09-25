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
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import com.vnt.ChangeApplyResult;
import com.vnt.NetworkResult;
import com.vnt.RuntimeChange;
import com.vnt.RuntimeEvent;
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
    private static final long SUBSCRIPTION_FETCH_RETRY_MS = 5_000L;
    private static final int DEFAULT_MTU = 1380;
    /** Rust 核心 P2P 栈的 IPv6 MTU 下限（vnt-core MIN_MTU） */
    private static final int MIN_MTU = 1280;

    private static volatile VntState state = VntState.stopped();
    private static volatile boolean uiVisible;
    private static volatile WeakReference<VntVpnService> instance = new WeakReference<>(null);
    private ScheduledExecutorService worker;
    private ScheduledFuture<?> refreshTask;
    private volatile VntNetwork network;
    private volatile VntApi api;
    /** 当前 VPN 接口使用的 CIDR；快照未携带固定 IP 时沿用（监听线程内使用） */
    private volatile String establishedCidr;
    /** 是否持有 TUN 设备（无网卡模式下运行期变更不走接口重建） */
    private volatile boolean tunActive;
    private long runtimeGeneration;
    private String activeProfileName;
    private String activeConfigJson;
    private boolean activeAllowIkev2;
    private String activeIp;
    private int activePrefixLen;
    private List<String> activeSubnetRoutes = Collections.emptyList();
    private final Map<String, VntApi.Traffic> trafficSamples = new HashMap<>();
    private long trafficSampleTime;
    private volatile boolean cancellationRequested;
    private String activeProfileId;
    private String activeSubscription;
    private String subscriptionInstanceId;
    private volatile boolean runtimeExitReported;

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
        start(context, profile, null);
    }

    static void start(Context context, VntConfigStore.Profile profile,
                      String prefetchedSubscriptionConfig) {
        Intent intent = new Intent(context, VntVpnService.class)
                .setAction(ACTION_START)
                .putExtra("id", profile.id)
                .putExtra("name", profile.name)
                .putExtra("json", profile.json)
                .putExtra("subscription", profile.subscription)
                .putExtra("prefetched_subscription_config", prefetchedSubscriptionConfig);
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
                String subscription = active.getString("subscription", "");
                String instanceId = active.getString("subscription_instance_id", "");
                startForeground(NOTIFICATION_ID, notification("正在恢复虚拟网络…", false));
                worker.execute(() -> connect(id, name, json, subscription, instanceId, null));
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
            String subscription = intent.getStringExtra("subscription");
            String prefetchedSubscriptionConfig = intent.getStringExtra(
                    "prefetched_subscription_config");
            String instanceId = subscription == null || subscription.isBlank()
                    ? "" : SubscriptionConfig.newInstanceId();
            cancellationRequested = false;
            getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit()
                    .putString("id", id).putString("name", name).putString("json", json)
                    .putString("subscription", subscription == null ? "" : subscription)
                    .putString("subscription_instance_id", instanceId).apply();
            startForeground(NOTIFICATION_ID, notification("正在建立虚拟网络…", false));
            worker.execute(() -> connect(id, name, json, subscription, instanceId,
                    prefetchedSubscriptionConfig));
        }
        return START_STICKY;
    }

    private void connect(String id, String name, String json, String subscription,
                         String instanceId, String prefetchedSubscriptionConfig) {
        cleanupNative();
        activeProfileId = id;
        activeProfileName = name;
        activeSubscription = subscription == null || subscription.isBlank() ? null : subscription;
        subscriptionInstanceId = activeSubscription == null ? null
                : instanceId == null || instanceId.isBlank() ? SubscriptionConfig.newInstanceId() : instanceId;
        publish(new VntState(VntState.Status.STARTING, id, name, null,
                "正在连接服务器并注册网络…", activeAllowIkev2,
                null, null, null, null, null));
        try {
            if (!VntManager.init()) throw new IllegalStateException("Rust 核心初始化失败");
            if (activeSubscription != null) {
                // 预取只用于尽早暴露服务端策略与设备模式；正式启动时 native 会
                // 重新等待服务端首份信封并按快照合并本地设置
                String fetchedJson = fetchSubscriptionConfigWithRetry(
                        id, name, prefetchedSubscriptionConfig);
                JSONObject fetched = new JSONObject(fetchedJson);
                JSONObject remote = fetched.getJSONObject("config");
                // 新核心把托管身份放在响应顶层，信封配置未必包含 network_code
                if (remote.optString("network_code").trim().isEmpty()) {
                    remote.put("network_code", fetched.optString("networkCode"));
                }
                json = SubscriptionConfig.runtime(remote, activeSubscription,
                        subscriptionInstanceId).toString();
            }
            startResolvedInstance(id, name, json);
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

    /** Retries only the remote subscription fetch; malformed fetched data remains a final error. */
    private String fetchSubscriptionConfigWithRetry(String id, String name,
                                                    String prefetchedSubscriptionConfig)
            throws InterruptedException {
        if (prefetchedSubscriptionConfig != null && !prefetchedSubscriptionConfig.isBlank()) {
            return prefetchedSubscriptionConfig;
        }
        return SubscriptionFetchRetry.fetch(
                () -> VntManager.fetchSubscriptionConfig(activeSubscription),
                () -> cancellationRequested,
                delayMs -> {
                    long deadline = SystemClock.elapsedRealtime() + delayMs;
                    while (!cancellationRequested && SystemClock.elapsedRealtime() < deadline) {
                        SystemClock.sleep(Math.min(1_000L,
                                deadline - SystemClock.elapsedRealtime()));
                    }
                },
                (attempt, error) -> {
                    String detail = rootMessage(error);
                    String message = "获取订阅配置失败（第 " + attempt + " 次）：" + detail
                            + "；5 秒后重试";
                    publish(new VntState(VntState.Status.STARTING, id, name, null, message,
                            activeAllowIkev2, null, null, null, null, null));
                    startForeground(NOTIFICATION_ID, notification(message, false));
                },
                SUBSCRIPTION_FETCH_RETRY_MS);
    }

    private void startResolvedInstance(String id, String name, String json) throws Exception {
        json = useBuiltInNat(json);
        activeConfigJson = json;
        JSONObject config = new JSONObject(json);
        activeSubnetRoutes = arrayStrings(config.optJSONArray("input"));
        activeAllowIkev2 = config.optBoolean("allow_ikev2", false);
        long generation = ++runtimeGeneration;
        VntNetwork created = VntManager.createNetwork(json);
        if (created == null) throw new IllegalStateException("Rust 核心无法创建网络实例");
        network = created;
        // createNetwork 时底层已在后台连接服务器并注册：网络已配置则立即返回，
        // 否则等待注册结果返回网段信息
        NetworkResult registered = created.getNetwork();
        if (cancellationRequested) throw new IllegalStateException("启动已取消");
        activeIp = registered.getIp();
        activePrefixLen = registered.getPrefixLen();
        establishedCidr = registered.toCidr();

        if (!created.isNoTun()) {
            ParcelFileDescriptor established = establishVpn(name, json,
                    registered.getIp(), registered.getPrefixLen());
            if (established == null) throw new IllegalStateException("Android 未能建立 VPN 接口");
            int tunFd = established.detachFd();
            created.startTun(tunFd);
            tunActive = true;
        }

        api = created.getApi();
        startRuntimeListener(created, generation);
        getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit()
                .putString("json", json).apply();
        VntState running = readState(id, name, activeIp);
        publish(running);
        startForeground(NOTIFICATION_ID, notification("已连接 · " + activeIp, true));
        startRefreshing();
    }

    private static String useBuiltInNat(String json) {
        try {
            JSONObject config = new JSONObject(json);
            config.remove("no_nat");
            return config.toString();
        } catch (Exception ignored) {
            return json;
        }
    }

    /**
     * 变更循环监听线程：Java 拥有这个阻塞监听，Rust 从不回调 Java。与 PC 端
     * cli/web 主循环一致，由 native 侧 RuntimeChangeManager 驱动：订阅连接
     * 与组网实例分离，运行期变更（含重建组网实例）都由管理器内部完成。
     */
    private void startRuntimeListener(VntNetwork expectedNetwork, long generation) {
        Thread listener = new Thread(
                () -> runRuntimeChangeLoop(expectedNetwork, generation), "vnt-runtime-listener");
        listener.setDaemon(true);
        listener.start();
    }

    private void runRuntimeChangeLoop(VntNetwork expectedNetwork, long generation) {
        try {
            while (!cancellationRequested && network == expectedNetwork
                    && generation == runtimeGeneration) {
                RuntimeEvent event = expectedNetwork.nextEvent();
                if (event.isInstanceStopped()) {
                    handleRuntimeLoopExit("组网实例已停止");
                    return;
                }
                RuntimeChange change = event.getChange();
                if (change == null) continue;
                Log.i("VNT", "运行期变更: " + change);
                if (!applyRuntimeChange(expectedNetwork, change)) return;
                Log.i("VNT", "运行期变更已应用");
            }
        } catch (Throwable error) {
            if (!cancellationRequested && network == expectedNetwork) {
                Log.w("VNT", "运行期变更循环失败: " + rootMessage(error));
                handleRuntimeLoopExit(rootMessage(error));
            }
        }
    }

    /**
     * 按快照自带标志应用一次运行期变更：需要新接口时先建立再携带 fd 应用，
     * 否则原地应用。返回 false 表示变更循环应结束（已按意外退出处理）。
     */
    private boolean applyRuntimeChange(VntNetwork expectedNetwork, RuntimeChange change) {
        try {
            if (expectedNetwork != network) return false;
            // 低于核心 MTU 下限的快照会被 native 拒绝：先本地拦截，避免白白重建接口
            Integer snapshotMtu = change.getMtu();
            if (snapshotMtu != null && snapshotMtu < MIN_MTU) {
                handleRuntimeLoopExit("快照 MTU " + snapshotMtu + " 低于下限 " + MIN_MTU);
                return false;
            }
            // 无网卡模式下两个标志都不走接口重建：组网实例由 native 内部重建
            boolean needsInterface = tunActive
                    && (change.isVpnRebuild() || change.isInstanceRebuild());
            if (needsInterface) {
                String cidr = change.getIp() != null ? change.getIp() : establishedCidr;
                int mtu = change.getMtu() != null ? change.getMtu() : configuredMtu();
                ParcelFileDescriptor replacement = establishVpnForChange(cidr, mtu,
                        change.getRoutes());
                if (replacement == null) throw new IllegalStateException("Android 未能重建 VPN 接口");
                int fd = replacement.detachFd();
                establishedCidr = cidr;
                ChangeApplyResult result = expectedNetwork.applyRuntimeChange(fd);
                if (result.isApplied()) {
                    commitRuntimeChangeApplied(cidr);
                    return true;
                }
                handleRuntimeLoopExit("携带新接口后仍未应用：" + result);
                return false;
            }
            ChangeApplyResult result = expectedNetwork.applyRuntimeChange();
            if (result.isApplied()) {
                refreshRuntimeApi();
                publishRuntimeState();
                return true;
            }
            if (tunActive && (result.isNeedFd() || result.isRebuild())) {
                // 未按 nextEvent 的标志重建接口：按快照参数补一次，携带 fd 应用
                String cidr = change.getIp() != null ? change.getIp() : establishedCidr;
                int mtu = change.getMtu() != null ? change.getMtu() : configuredMtu();
                ParcelFileDescriptor replacement = establishVpnForChange(cidr, mtu,
                        change.getRoutes());
                if (replacement == null) throw new IllegalStateException("Android 未能重建 VPN 接口");
                int fd = replacement.detachFd();
                establishedCidr = cidr;
                ChangeApplyResult retry = expectedNetwork.applyRuntimeChange(fd);
                if (retry.isApplied()) {
                    commitRuntimeChangeApplied(cidr);
                    return true;
                }
                handleRuntimeLoopExit("携带新接口后仍未应用：" + retry);
                return false;
            }
            handleRuntimeLoopExit("运行期变更未能应用：" + result);
            return false;
        } catch (Throwable error) {
            handleRuntimeLoopExit(rootMessage(error));
            return false;
        }
    }

    /** 接口/实例重建后刷新对外状态：虚拟 IP、查询接口、通知。 */
    private void commitRuntimeChangeApplied(String cidr) {
        if (cidr != null && !cidr.isBlank()) {
            String[] parts = cidr.split("/", 2);
            activeIp = parts[0];
            if (parts.length == 2) {
                try {
                    activePrefixLen = Integer.parseInt(parts[1]);
                } catch (NumberFormatException ignored) { }
            }
        }
        refreshRuntimeApi();
        publishRuntimeState();
    }

    /** 实例可能被内部重建，重新取查询接口（对应 cli 的 ipc.publish）。 */
    private void refreshRuntimeApi() {
        VntNetwork current = network;
        if (current == null) return;
        try {
            api = current.getApi();
        } catch (Throwable error) {
            Log.w("VNT", "刷新查询接口失败: " + rootMessage(error));
        }
    }

    private void publishRuntimeState() {
        try {
            worker.execute(() -> {
                if (cancellationRequested) return;
                try {
                    publish(readState(activeProfileId, activeProfileName, activeIp));
                    startForeground(NOTIFICATION_ID, notification("已连接 · " + activeIp, true));
                } catch (Throwable error) {
                    Log.w("VNT", "刷新运行期变更后的状态失败: " + rootMessage(error));
                }
            });
        } catch (RejectedExecutionException ignored) { }
    }

    /** 变更循环意外结束（实例自行停止或应用失败）：报告错误并停止服务。 */
    private void handleRuntimeLoopExit(String reason) {
        if (runtimeExitReported) return;
        runtimeExitReported = true;
        if (cancellationRequested) return;
        try {
            worker.execute(() -> {
                if (cancellationRequested) return;
                String profileId = activeProfileId;
                String profileName = activeProfileName;
                cleanupNative();
                clearActiveConnection();
                publish(new VntState(VntState.Status.ERROR, profileId, profileName, null,
                        "连接已中断：" + reason, false, null, null, null, null, null));
                stopForeground(STOP_FOREGROUND_REMOVE);
                stopSelf();
            });
        } catch (RejectedExecutionException ignored) { }
    }

    private void refresh() {
        VntState current = state;
        if (!uiVisible || current.status != VntState.Status.RUNNING || api == null) return;
        try { publish(readState(current.profileId, current.profileName, current.ip)); }
        catch (Throwable ignored) { }
    }

    private ParcelFileDescriptor establishVpn(String name, String json, String ip, int prefixLen)
            throws Exception {
        JSONObject config = new JSONObject(json);
        Builder builder = new Builder()
                .setSession(sessionName(name, config))
                .setMtu(clampMtu(config.optInt("mtu", DEFAULT_MTU)))
                .addAddress(ip, prefixLen);
        builder.addDisallowedApplication(getPackageName());
        for (VpnRouteSet.Route route : VpnRouteSet.build(ip, prefixLen,
                arrayStrings(config.optJSONArray("output")),
                arrayStrings(config.optJSONArray("input")), activeSubnetRoutes)) {
            addRoute(builder, route.address(), route.prefix());
        }
        return builder.establish();
    }

    /** 按运行期快照参数重建 VPN 接口（完整入站路由以快照为准）。 */
    private ParcelFileDescriptor establishVpnForChange(String cidr, int mtu, List<String> routes)
            throws Exception {
        String[] parts = cidr.split("/", 2);
        String ip = parts[0];
        int prefixLen = parts.length == 2 ? Integer.parseInt(parts[1]) : 24;
        JSONObject config = activeConfigJson == null || activeConfigJson.isBlank()
                ? new JSONObject() : new JSONObject(activeConfigJson);
        Builder builder = new Builder()
                .setSession(sessionName(activeProfileName, config))
                .setMtu(clampMtu(mtu))
                .addAddress(ip, prefixLen);
        builder.addDisallowedApplication(getPackageName());
        for (VpnRouteSet.Route route : VpnRouteSet.rebuild(ip, prefixLen, routes)) {
            addRoute(builder, route.address(), route.prefix());
        }
        return builder.establish();
    }

    /** VPN 接口会话名：配置的 tun_name 优先，否则 "VNT · 配置名"。 */
    private static String sessionName(String name, JSONObject config) {
        String session = config == null ? "" : config.optString("tun_name", "").trim();
        if (session.isEmpty()) session = "VNT · " + (name == null || name.isBlank() ? "VNT" : name);
        return session;
    }

    private int configuredMtu() {
        try {
            if (activeConfigJson != null && !activeConfigJson.isBlank()) {
                return new JSONObject(activeConfigJson).optInt("mtu", DEFAULT_MTU);
            }
        } catch (Exception ignored) { }
        return DEFAULT_MTU;
    }

    private static int clampMtu(int mtu) { return Math.max(MIN_MTU, Math.min(9000, mtu)); }

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
        List<String> tunnelListenAddresses = api.getTunnelListenAddresses();
        return new VntState(VntState.Status.RUNNING, id, name, ip,
                "", activeAllowIkev2, clients, servers, routes, nat, network, tunnelListenAddresses);
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
        stopCurrentInstance();
        try { VntManager.destroy(); } catch (Throwable ignored) { }
        activeProfileId = null;
        activeProfileName = null;
        activeConfigJson = null;
        activeAllowIkev2 = false;
        activeSubscription = null;
        subscriptionInstanceId = null;
        runtimeExitReported = false;
    }

    private void stopCurrentInstance() {
        stopRefreshing();
        api = null;
        establishedCidr = null;
        tunActive = false;
        if (network != null) {
            try { network.stop(); } catch (Throwable ignored) { }
            network = null;
        }
        activeIp = null;
        activePrefixLen = 0;
        activeSubnetRoutes = Collections.emptyList();
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

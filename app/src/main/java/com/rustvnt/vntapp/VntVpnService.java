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
import com.vnt.RegisterResult;
import com.vnt.VntApi;
import com.vnt.VntManager;
import com.vnt.VntNetwork;
import com.vnt.TunRebuildRequest;
import org.json.JSONArray;
import org.json.JSONObject;
import java.lang.ref.WeakReference;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
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
    private static final long SUBSCRIPTION_FETCH_RETRY_MS = 5_000L;

    private static volatile VntState state = VntState.stopped();
    private static volatile boolean uiVisible;
    private static volatile WeakReference<VntVpnService> instance = new WeakReference<>(null);
    private ScheduledExecutorService worker;
    private ScheduledFuture<?> refreshTask;
    private volatile VntNetwork network;
    private volatile VntApi api;
    private ParcelFileDescriptor vpnInterface;
    private final Object subscriptionUpdatesLock = new Object();
    private PendingSubscriptionUpdate pendingSubscriptionUpdate;
    private boolean subscriptionDrainScheduled;
    private long runtimeGeneration;
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
    private String activeProfileId;
    private String activeSubscription;
    private String subscriptionInstanceId;
    private long appliedSubscriptionRevision;
    private JSONObject lastGoodSubscriptionConfig;
    private boolean applyingSubscriptionUpdate;

    private record PendingSubscriptionUpdate(long generation, VntNetwork network, VntApi api,
                                             long revision, JSONObject config) { }

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
                .putExtra("subscription_revision", profile.subscriptionRevision)
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
                long revision = active.getLong("subscription_revision", 0);
                String instanceId = active.getString("subscription_instance_id", "");
                startForeground(NOTIFICATION_ID, notification("正在恢复虚拟网络…", false));
                worker.execute(() -> connect(id, name, json, subscription, revision, instanceId, null));
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
            long revision = intent.getLongExtra("subscription_revision", 0);
            String instanceId = subscription == null || subscription.isBlank()
                    ? "" : SubscriptionConfig.newInstanceId();
            cancellationRequested = false;
            getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit()
                    .putString("id", id).putString("name", name).putString("json", json)
                    .putString("subscription", subscription == null ? "" : subscription)
                    .putLong("subscription_revision", revision)
                    .putString("subscription_instance_id", instanceId).apply();
            startForeground(NOTIFICATION_ID, notification("正在建立虚拟网络…", false));
            worker.execute(() -> connect(id, name, json, subscription, revision, instanceId,
                    prefetchedSubscriptionConfig));
        }
        return START_STICKY;
    }

    private void connect(String id, String name, String json, String subscription,
                         long appliedRevision, String instanceId,
                         String prefetchedSubscriptionConfig) {
        cleanupNative();
        activeProfileId = id;
        activeProfileName = name;
        activeSubscription = subscription == null || subscription.isBlank() ? null : subscription;
        appliedSubscriptionRevision = Math.max(0, appliedRevision);
        subscriptionInstanceId = activeSubscription == null ? null
                : instanceId == null || instanceId.isBlank() ? SubscriptionConfig.newInstanceId() : instanceId;
        publish(new VntState(VntState.Status.STARTING, id, name, null,
                "正在连接服务器并注册网络…", activeAllowIkev2,
                null, null, null, null, null));
        try {
            if (!VntManager.init()) throw new IllegalStateException("Rust 核心初始化失败");
            long targetRevision = 0;
            JSONObject remote = null;
            if (activeSubscription != null) {
                String fetchedJson = fetchSubscriptionConfigWithRetry(
                        id, name, prefetchedSubscriptionConfig);
                JSONObject fetched = new JSONObject(fetchedJson);
                targetRevision = fetched.getLong("revision");
                remote = fetched.getJSONObject("config");
                json = SubscriptionConfig.runtime(remote, activeSubscription,
                        appliedSubscriptionRevision, subscriptionInstanceId).toString();
            }
            startResolvedInstance(id, name, json);
            if (activeSubscription != null) {
                lastGoodSubscriptionConfig = remote;
                api.markSubscriptionAppliedLocally(targetRevision);
                commitSubscriptionRevision(targetRevision, json);
            }
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
        RegisterResult registration = created.register();
        if (cancellationRequested) throw new IllegalStateException("启动已取消");
        activeIp = registration.getIp();
        activePrefixLen = registration.getPrefixLen();

        if (!created.isNoTun()) {
            vpnInterface = establishVpn(name, json, registration.getIp(), registration.getPrefixLen());
            if (vpnInterface == null) throw new IllegalStateException("Android 未能建立 VPN 接口");
            int tunFd = vpnInterface.detachFd();
            vpnInterface = null;
            created.startTun(tunFd);
            appliedSubnetRouteCidrs = VpnRouteSet.cidrs(activeSubnetRoutes);
            created.listenTunRebuild(request -> handleTunRebuild(created, generation, request));
        }

        api = created.getApi();
        if (activeSubscription != null) startSubscriptionListener(created, api, generation);
        VntState running = readState(id, name, registration.getIp());
        publish(running);
        startForeground(NOTIFICATION_ID, notification("已连接 · " + registration.getIp(), true));
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

    private void startSubscriptionListener(VntNetwork expectedNetwork, VntApi expectedApi,
                                           long generation) {
        Thread listener = new Thread(() -> {
            while (!cancellationRequested && network == expectedNetwork
                    && generation == runtimeGeneration) {
                try {
                    String raw = expectedApi.waitSubscriptionConfigUpdate();
                    if (raw == null) return;
                    JSONObject update = new JSONObject(raw);
                    if (!update.optBoolean("serverVerified", false)) continue;
                    enqueueSubscriptionUpdate(new PendingSubscriptionUpdate(generation, expectedNetwork,
                            expectedApi, update.getLong("revision"), update.getJSONObject("config")));
                } catch (Throwable error) {
                    if (!cancellationRequested && network == expectedNetwork) {
                        Log.w("VNT", "等待订阅配置更新失败: " + rootMessage(error));
                    }
                    return;
                }
            }
        }, "vnt-subscription-config-listener");
        listener.setDaemon(true);
        listener.start();
    }

    private void enqueueSubscriptionUpdate(PendingSubscriptionUpdate next) {
        PendingSubscriptionUpdate superseded = null;
        String settledStatus = null;
        synchronized (subscriptionUpdatesLock) {
            if (next.generation() != runtimeGeneration || next.network() != network) return;
            settledStatus = SubscriptionConfig.settledAckStatus(
                    next.revision(), appliedSubscriptionRevision);
            if (settledStatus == null && pendingSubscriptionUpdate != null) {
                if (pendingSubscriptionUpdate.revision() >= next.revision()) {
                    superseded = next;
                } else {
                    superseded = pendingSubscriptionUpdate;
                    pendingSubscriptionUpdate = next;
                }
            } else if (settledStatus == null) {
                pendingSubscriptionUpdate = next;
            }
            if (settledStatus == null && superseded == null && !subscriptionDrainScheduled) {
                subscriptionDrainScheduled = true;
                try { worker.execute(this::drainSubscriptionUpdates); }
                catch (RejectedExecutionException ignored) { subscriptionDrainScheduled = false; }
            }
        }
        if (settledStatus != null) {
            tryAckSubscription(next.api(), next.revision(), settledStatus, "", null);
            return;
        }
        if (superseded != null) {
            tryAckSubscription(superseded.api(), superseded.revision(), "superseded", "", null);
        }
    }

    private void drainSubscriptionUpdates() {
        while (!cancellationRequested) {
            PendingSubscriptionUpdate update;
            synchronized (subscriptionUpdatesLock) {
                update = pendingSubscriptionUpdate;
                pendingSubscriptionUpdate = null;
                if (update == null) {
                    subscriptionDrainScheduled = false;
                    return;
                }
            }
            if (update.generation() == runtimeGeneration && update.network() == network) {
                applySubscriptionUpdate(update);
            }
        }
    }

    private void applySubscriptionUpdate(PendingSubscriptionUpdate update) {
        String settledStatus = SubscriptionConfig.settledAckStatus(
                update.revision(), appliedSubscriptionRevision);
        if (settledStatus != null) {
            tryAckSubscription(update.api(), update.revision(), settledStatus, "", null);
            return;
        }
        if (applyingSubscriptionUpdate) return;
        applyingSubscriptionUpdate = true;
        long previousRevision = appliedSubscriptionRevision;
        JSONObject previous = lastGoodSubscriptionConfig;
        try {
            JSONObject candidateRuntime = SubscriptionConfig.runtime(update.config(), activeSubscription,
                    previousRevision, subscriptionInstanceId);
            JSONObject result = new JSONObject(update.api().reconfigure(candidateRuntime.toString()));
            if (!result.optBoolean("ok", false)) {
                JSONObject error = result.optJSONObject("error");
                if (error != null && "INSTANCE_RESTART".equals(error.optString("fallback"))) {
                    restartSubscriptionUpdate(update, candidateRuntime, previous, previousRevision);
                } else {
                    String message = error == null ? "配置实时应用失败" : error.optString("message");
                    tryAckSubscription(update.api(), update.revision(), "error", message, error);
                }
                return;
            }
            JSONObject report = result.getJSONObject("report");
            if ("INSTANCE_RESTART".equals(report.optString("action"))) {
                restartSubscriptionUpdate(update, candidateRuntime, previous, previousRevision);
                return;
            }
            commitAppliedSubscription(update.api(), update.revision(), candidateRuntime.toString());
            lastGoodSubscriptionConfig = update.config();
            tryAckSubscription(update.api(), update.revision(), "applied", "", report);
        } catch (Throwable error) {
            tryAckSubscription(update.api(), update.revision(), "error", rootMessage(error), null);
        } finally {
            applyingSubscriptionUpdate = false;
        }
    }

    private void restartSubscriptionUpdate(PendingSubscriptionUpdate update, JSONObject candidate,
                                           JSONObject previous, long previousRevision) {
        tryAckSubscription(update.api(), update.revision(), "staged", "", null);
        try {
            stopCurrentInstance();
            startResolvedInstance(activeProfileId, activeProfileName, candidate.toString());
            commitAppliedSubscription(api, update.revision(), candidate.toString());
            lastGoodSubscriptionConfig = update.config();
            tryAckSubscription(api, update.revision(), "applied", "", null);
        } catch (Throwable updateError) {
            String message = rootMessage(updateError);
            try {
                stopCurrentInstance();
                if (previous == null) throw new IllegalStateException("没有可恢复的订阅配置");
                JSONObject rollback = SubscriptionConfig.runtime(previous, activeSubscription,
                        previousRevision, subscriptionInstanceId);
                startResolvedInstance(activeProfileId, activeProfileName, rollback.toString());
                tryAckSubscription(api, update.revision(), "error", message, null);
                startForeground(NOTIFICATION_ID, notification("订阅更新失败，已恢复上一版本", true));
            } catch (Throwable rollbackError) {
                cancellationRequested = true;
                String profileId = activeProfileId;
                String profileName = activeProfileName;
                cleanupNative();
                clearActiveConnection();
                publish(new VntState(VntState.Status.ERROR, profileId, profileName, null,
                        "订阅更新及回滚失败：" + rootMessage(rollbackError), false,
                        null, null, null, null, null));
                stopForeground(STOP_FOREGROUND_REMOVE);
                stopSelf();
            }
        }
    }

    private void commitAppliedSubscription(VntApi targetApi, long revision, String json) throws Exception {
        targetApi.markSubscriptionAppliedLocally(revision);
        JSONObject config = new JSONObject(json);
        activeConfigJson = json;
        activeSubnetRoutes = arrayStrings(config.optJSONArray("input"));
        activeAllowIkev2 = config.optBoolean("allow_ikev2", false);
        VntApi.NetworkInfo networkInfo = targetApi.getNetwork();
        if (networkInfo != null) {
            activeIp = networkInfo.ip();
            activePrefixLen = networkInfo.prefixLen();
        }
        commitSubscriptionRevision(revision, json);
    }

    private boolean tryAckSubscription(VntApi targetApi, long revision, String status,
                                       String error, JSONObject report) {
        try {
            JSONObject ack = new JSONObject().put("revision", revision).put("status", status)
                    .put("overridden_fields", new JSONArray());
            if (error != null && !error.isBlank()) ack.put("error", error);
            if (report != null) {
                ack.put("apply_mode", report.optString("action"));
                ack.put("changed_fields", report.optJSONArray("changed_fields") == null
                        ? new JSONArray() : report.getJSONArray("changed_fields"));
            }
            if ("applied".equals(status)) appendEffectiveRuntimeMetadata(ack);
            return targetApi.ackSubscriptionConfig(ack.toString());
        } catch (Throwable ackError) {
            Log.w("VNT", "订阅配置确认失败: " + rootMessage(ackError));
            return false;
        }
    }

    private void appendEffectiveRuntimeMetadata(JSONObject ack) throws Exception {
        String json = activeConfigJson;
        if (json == null || json.isBlank()) {
            throw new IllegalStateException("没有已生效的订阅配置");
        }
        JSONObject config = new JSONObject(json);
        String deviceName = config.optString("device_name", "").trim();
        if (deviceName.isEmpty()) deviceName = config.optString("device_id", "").trim();
        ack.put("effective_device_name", deviceName);
        if (activeIp != null && !activeIp.isBlank()) {
            ack.put("effective_ip", activeIp);
            ack.put("effective_prefix_len", activePrefixLen);
        }
        JSONArray output = config.optJSONArray("output");
        ack.put("effective_output", output == null ? new JSONArray() : output);
        ack.put("allow_ikev2", config.optBoolean("allow_ikev2", false));
        ack.put("allow_wireguard", config.optBoolean("allow_wireguard", false));
        ack.put("allow_mapping", config.optBoolean("allow_mapping", false));
        ack.put("effective_config_sha256", sha256Hex(json));
    }

    private static String sha256Hex(String value) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder(digest.length * 2);
        for (byte item : digest) result.append(String.format("%02x", item & 0xff));
        return result.toString();
    }

    private void commitSubscriptionRevision(long revision, String json) {
        appliedSubscriptionRevision = revision;
        new VntConfigStore(this).updateSubscriptionRevision(activeProfileId, revision);
        getSharedPreferences(ACTIVE_PREFS, MODE_PRIVATE).edit()
                .putLong("subscription_revision", revision).putString("json", json).apply();
        sendBroadcast(new Intent(ACTION_STATE).setPackage(getPackageName()));
    }

    private void stopCurrentInstance() {
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
        activeIp = null;
        activePrefixLen = 0;
        activeSubnetRoutes = Collections.emptyList();
        appliedSubnetRouteCidrs = Collections.emptySet();
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
        String session = config.optString("tun_name", "").trim();
        if (session.isEmpty()) session = "VNT · " + name;
        Builder builder = new Builder()
                .setSession(session)
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

    /** Runs on the Java-owned TUN listener thread, never from Rust into Java. */
    private void handleTunRebuild(VntNetwork expectedNetwork, long generation,
                                  TunRebuildRequest request) throws Exception {
        if (cancellationRequested || generation != runtimeGeneration || network != expectedNetwork) {
            expectedNetwork.rejectTunRebuild(request.getRequestId(), "VNT instance was replaced");
            return;
        }
        ParcelFileDescriptor replacement = establishVpnForRequest(request);
        if (replacement == null) {
            expectedNetwork.rejectTunRebuild(request.getRequestId(),
                    "VpnService.Builder.establish returned null");
            return;
        }
        int fd = replacement.detachFd();
        expectedNetwork.replaceTun(request.getRequestId(), fd);
        try {
            worker.execute(() -> {
                if (cancellationRequested || generation != runtimeGeneration || network != expectedNetwork) return;
                activeIp = request.getIp();
                activePrefixLen = request.getPrefixLen();
                appliedSubnetRouteCidrs = VpnRouteSet.cidrs(arrayStrings(request.getRoutes()));
                try {
                    publish(readState(activeProfileId, activeProfileName, activeIp));
                    startForeground(NOTIFICATION_ID, notification("已连接 · " + activeIp, true));
                } catch (Throwable error) {
                    Log.w("VNT", "刷新 TUN 重建后的状态失败: " + rootMessage(error));
                }
            });
        } catch (RejectedExecutionException ignored) { }
    }

    private ParcelFileDescriptor establishVpnForRequest(TunRebuildRequest request) throws Exception {
        String session = request.getSessionName();
        if (session == null || session.isBlank()) session = "VNT · " + activeProfileName;
        Builder builder = new Builder().setSession(session)
                .setMtu(Math.max(576, Math.min(9000, request.getMtu())))
                .addAddress(request.getIp(), request.getPrefixLen());
        builder.addDisallowedApplication(getPackageName());
        for (VpnRouteSet.Route route : VpnRouteSet.rebuild(request.getIp(), request.getPrefixLen(),
                arrayStrings(request.getRoutes()))) {
            addRoute(builder, route.address(), route.prefix());
        }
        return builder.establish();
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
        synchronized (subscriptionUpdatesLock) {
            pendingSubscriptionUpdate = null;
            subscriptionDrainScheduled = false;
        }
        stopCurrentInstance();
        try { VntManager.destroy(); } catch (Throwable ignored) { }
        activeProfileId = null;
        activeProfileName = null;
        activeConfigJson = null;
        activeAllowIkev2 = false;
        activeSubscription = null;
        subscriptionInstanceId = null;
        appliedSubscriptionRevision = 0;
        lastGoodSubscriptionConfig = null;
        applyingSubscriptionUpdate = false;
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

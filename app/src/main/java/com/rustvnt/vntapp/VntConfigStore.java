package com.rustvnt.vntapp;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

final class VntConfigStore {
    private static final String PREFS = "vnt_profiles";
    private static final String KEY = "profiles";
    private final SharedPreferences preferences;

    VntConfigStore(Context context) {
        preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    synchronized List<Profile> all() {
        List<Profile> result = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(preferences.getString(KEY, "[]"));
            for (int i = 0; i < array.length(); i++) result.add(Profile.fromStorage(array.getJSONObject(i)));
        } catch (Exception ignored) { }
        return result;
    }

    synchronized Profile find(String id) {
        for (Profile profile : all()) if (profile.id.equals(id)) return profile;
        return null;
    }

    synchronized String deviceId() {
        String id = preferences.getString("device_id", null);
        if (id == null || id.isBlank()) {
            id = UUID.randomUUID().toString();
            preferences.edit().putString("device_id", id).apply();
        }
        return id;
    }

    synchronized void save(Profile profile) {
        List<Profile> profiles = all();
        boolean replaced = false;
        for (int i = 0; i < profiles.size(); i++) {
            if (profiles.get(i).id.equals(profile.id)) {
                profiles.set(i, profile);
                replaced = true;
                break;
            }
        }
        if (!replaced) profiles.add(profile);
        write(profiles);
    }

    synchronized void delete(String id) {
        List<Profile> profiles = all();
        profiles.removeIf(profile -> profile.id.equals(id));
        write(profiles);
    }

    private void write(List<Profile> profiles) {
        JSONArray array = new JSONArray();
        for (Profile profile : profiles) array.put(profile.toStorage());
        preferences.edit().putString(KEY, array.toString()).apply();
    }

    static final class Profile {
        static final String MODE_MANUAL = "manual";
        static final String MODE_SUBSCRIPTION = "subscription";
        final String id;
        final String name;
        final String json;
        final String mode;
        final String subscription;

        Profile(String id, String name, String json) {
            this(id, name, json, MODE_MANUAL, "");
        }

        Profile(String id, String name, String json, String mode, String subscription) {
            this.id = id;
            this.name = name;
            this.json = json;
            this.mode = MODE_SUBSCRIPTION.equals(mode) ? MODE_SUBSCRIPTION : MODE_MANUAL;
            this.subscription = subscription == null ? "" : subscription;
        }

        static Profile createSubscription(String name, String subscription, Profile existing) {
            String value = subscription == null ? "" : subscription.trim();
            if (!value.startsWith("vnt2://join/2/")) {
                throw new IllegalArgumentException("订阅链接格式无效");
            }
            String title = name == null || name.trim().isEmpty() ? "订阅配置" : name.trim();
            String id = existing == null ? UUID.randomUUID().toString() : existing.id;
            return new Profile(id, title, "{}", MODE_SUBSCRIPTION, value);
        }

        static Profile create(String name, String server, String code, String password,
                              String deviceId, String deviceName, String ip, int mtu, boolean compress,
                              boolean rtx, boolean fec, boolean noPunch, boolean noBroadcast, boolean allowIkev2,
                              boolean noTun, String peerAddress, String turn, String punchModel,
                              String outputRoutes, String inputRoutes, String subnetMapping,
                               boolean autoSyncSubnet, String certMode,
                               String tunnelPort, String portMapping, boolean allowMapping,
                               String udpStun, String tcpStun) throws Exception {
            validateBasicConfig(server, code, ip);
            JSONObject config = new JSONObject();
            JSONArray servers = new JSONArray();
            for (String value : server.split("[\\n,]")) if (!value.trim().isEmpty()) servers.put(value.trim());
            String fixedIp = ip.trim();
            config.put("server", servers);
            config.put("network_code", code.trim());
            if (!password.isEmpty()) config.put("password", password);
            if (deviceId.trim().isEmpty()) throw new IllegalArgumentException("设备 ID 不能为空");
            config.put("device_id", deviceId.trim());
            config.put("device_name", deviceName.trim().isEmpty() ? Build.MODEL : deviceName.trim());
            if (!fixedIp.isEmpty()) config.put("ip", fixedIp);
            config.put("mtu", mtu);
            config.put("compress", compress);
            config.put("rtx", rtx);
            config.put("fec", fec);
            config.put("no_punch", noPunch);
            config.put("no_broadcast", noBroadcast);
            config.put("allow_ikev2", allowIkev2);
            config.put("device_mode", noTun ? "no" : "tun");
            config.put("auto_sync_subnet", autoSyncSubnet);
            config.put("allow_mapping", allowMapping);
            config.put("cert_mode", certMode.trim().isEmpty() ? "skip" : certMode.trim());
            if (!tunnelPort.trim().isEmpty()) {
                int port = Integer.parseInt(tunnelPort.trim());
                if (port < 0 || port > 65535) throw new IllegalArgumentException("隧道端口必须在 0-65535 之间");
                config.put("tunnel_port", port);
            }
            JSONArray input = new JSONArray();
            for (String value : inputRoutes.split("[\\n]")) if (!value.trim().isEmpty()) input.put(value.trim());
            config.put("input", input);
            JSONArray output = new JSONArray();
            for (String value : outputRoutes.split("[\\n,]")) if (!value.trim().isEmpty()) output.put(value.trim());
            config.put("output", output);
            JSONArray peerAddresses = new JSONArray();
            for (String value : peerAddress.split("[\\n,]")) if (!value.trim().isEmpty()) peerAddresses.put(value.trim());
            config.put("peer_address", peerAddresses);
            JSONArray turns = new JSONArray();
            for (String value : turn.split("[\\n]")) if (!value.trim().isEmpty()) turns.put(value.trim());
            config.put("turn", turns);
            JSONArray punchModels = new JSONArray();
            for (String value : punchModel.split("[\\n]")) if (!value.trim().isEmpty()) punchModels.put(value.trim());
            config.put("punch_model", punchModels);
            JSONArray subnetMappings = new JSONArray();
            for (String value : subnetMapping.split("[\\n]")) if (!value.trim().isEmpty()) subnetMappings.put(value.trim());
            config.put("subnet_mapping", subnetMappings);
            JSONArray mappings = new JSONArray();
            for (String value : portMapping.split("[\\n]")) if (!value.trim().isEmpty()) mappings.put(value.trim());
            config.put("port_mapping", mappings);
            JSONArray udpStuns = new JSONArray();
            for (String value : udpStun.split("[\\n,]")) if (!value.trim().isEmpty()) udpStuns.put(value.trim());
            config.put("udp_stun", udpStuns);
            JSONArray tcpStuns = new JSONArray();
            for (String value : tcpStun.split("[\\n,]")) if (!value.trim().isEmpty()) tcpStuns.put(value.trim());
            config.put("tcp_stun", tcpStuns);
            String title = name.trim().isEmpty() ? code.trim() : name.trim();
            return new Profile(UUID.randomUUID().toString(), title, config.toString());
        }

        static void validateBasicConfig(String server, String code, String ip) {
            if (code.trim().isEmpty()) throw new IllegalArgumentException("网络编号不能为空");
            int serverCount = 0;
            for (String value : server.split("[\\n,]")) if (!value.trim().isEmpty()) serverCount++;
            if ((serverCount == 0 || serverCount > 1) && ip.trim().isEmpty()) {
                throw new IllegalArgumentException(serverCount == 0
                        ? "未配置服务器时必须填写虚拟 IP/CIDR"
                        : "配置多个服务器时必须填写虚拟 IP/CIDR");
            }
        }

        static Profile createFromQr(String code, List<String> servers, int mtu, String password,
                                    boolean allowIkev2, String deviceId) throws Exception {
            return create(code, String.join("\n", servers), code, password, deviceId, Build.MODEL,
                    "", mtu, false, false, false, false, false, allowIkev2, false,
                    "", "", "", "", "", "", false,
                    "skip", "", "", false, "", "");
        }

        Profile withId(String existingId) { return new Profile(existingId, name, json, mode, subscription); }

        boolean isSubscription() { return MODE_SUBSCRIPTION.equals(mode); }

        JSONObject config() {
            try { return new JSONObject(json); } catch (Exception error) { return new JSONObject(); }
        }

        JSONObject toStorage() {
            try {
                JSONObject value = new JSONObject().put("id", id).put("name", name).put("mode", mode);
                if (isSubscription()) {
                    value.put("subscription", subscription);
                } else {
                    value.put("json", json);
                }
                return value;
            }
            catch (Exception impossible) { return new JSONObject(); }
        }

        static Profile fromStorage(JSONObject value) {
            String mode = value.optString("mode", MODE_MANUAL);
            return new Profile(value.optString("id"), value.optString("name"),
                    value.optString("json", "{}"), mode, value.optString("subscription"));
        }
    }
}

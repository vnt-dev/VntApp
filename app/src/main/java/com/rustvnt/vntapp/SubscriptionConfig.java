package com.rustvnt.vntapp;

import org.json.JSONArray;
import org.json.JSONObject;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

final class SubscriptionConfig {
    private SubscriptionConfig() { }

    static String newInstanceId() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        StringBuilder result = new StringBuilder(64);
        for (byte value : bytes) result.append(String.format("%02x", value & 0xff));
        return result.toString();
    }

    static JSONObject runtime(JSONObject remote, String subscription, long appliedRevision,
                              String instanceId) throws Exception {
        JSONObject config = new JSONObject(remote.toString());
        if (config.optString("network_code").trim().isEmpty()) {
            throw new IllegalArgumentException("订阅配置缺少 network_code");
        }
        // Android has only TUN and no-device modes.  Historical desktop
        // values such as tap must remain startable after a profile migrates
        // to Android, so only an explicit "no" keeps no-device behavior.
        String mode = config.optString("device_mode", "tun");
        config.put("device_mode", requiresVpn(mode) ? "tun" : "no");
        config.remove("outbound_interface");
        config.remove("ctrl_port");
        config.remove("no_nat");
        config.put("subscription", subscription);
        config.put("subscription_revision", Math.max(0, appliedRevision));
        config.put("subscription_instance_id", instanceId);
        return config;
    }

    static boolean sameEffective(JSONObject left, JSONObject right) {
        try {
            return canonical(effective(left)).equals(canonical(effective(right)));
        } catch (Exception error) {
            return false;
        }
    }

    static String settledAckStatus(long incomingRevision, long appliedRevision) {
        if (incomingRevision == appliedRevision) return "applied";
        if (incomingRevision < appliedRevision) return "superseded";
        return null;
    }

    static boolean requiresVpn(String deviceMode) {
        return deviceMode == null || !"no".equalsIgnoreCase(deviceMode.trim());
    }

    private static JSONObject effective(JSONObject source) throws Exception {
        JSONObject value = new JSONObject(source.toString());
        value.remove("outbound_interface");
        value.remove("ctrl_port");
        value.remove("no_nat");
        value.remove("subscription");
        value.remove("subscription_revision");
        value.remove("subscription_instance_id");
        return value;
    }

    private static String canonical(Object value) {
        if (value == null || value == JSONObject.NULL) return "null";
        if (value instanceof JSONObject object) {
            List<String> keys = new ArrayList<>();
            Iterator<String> iterator = object.keys();
            while (iterator.hasNext()) keys.add(iterator.next());
            Collections.sort(keys);
            StringBuilder result = new StringBuilder("{");
            for (String key : keys) result.append(JSONObject.quote(key)).append(':')
                    .append(canonical(object.opt(key))).append(',');
            return result.append('}').toString();
        }
        if (value instanceof JSONArray array) {
            StringBuilder result = new StringBuilder("[");
            for (int i = 0; i < array.length(); i++) result.append(canonical(array.opt(i))).append(',');
            return result.append(']').toString();
        }
        return value instanceof String ? JSONObject.quote((String) value) : String.valueOf(value);
    }
}

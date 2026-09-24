package com.rustvnt.vntapp;

import org.json.JSONObject;
import java.security.SecureRandom;

final class SubscriptionConfig {
    private SubscriptionConfig() { }

    static String newInstanceId() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        StringBuilder result = new StringBuilder(64);
        for (byte value : bytes) result.append(String.format("%02x", value & 0xff));
        return result.toString();
    }

    /**
     * 组装订阅模式交给 native 的配置 JSON：以服务端托管的策略字段为本地配置
     * 基底，身份（network_code/device_id/ip/设备名）由 native 侧等待首份订阅
     * 信封后以信封为准；链接凭据与任务级实例 ID 随 JSON 一并下发。
     */
    static JSONObject runtime(JSONObject remote, String subscription, String instanceId)
            throws Exception {
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
        config.put("subscription_instance_id", instanceId);
        return config;
    }

    static boolean requiresVpn(String deviceMode) {
        return deviceMode == null || !"no".equalsIgnoreCase(deviceMode.trim());
    }
}

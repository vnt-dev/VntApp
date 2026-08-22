package com.vnt;

import org.json.JSONObject;

public final class RegisterResult {
    private final String ip;
    private final int prefixLen;
    private final String gateway;
    private final String broadcast;

    private RegisterResult(String ip, int prefixLen, String gateway, String broadcast) {
        this.ip = ip;
        this.prefixLen = prefixLen;
        this.gateway = gateway;
        this.broadcast = broadcast;
    }

    static RegisterResult fromJson(String json) throws VntException {
        try {
            JSONObject object = new JSONObject(json);
            if (!object.getBoolean("success")) {
                throw new VntException(object.optString("error", "注册被服务器拒绝"));
            }
            return new RegisterResult(object.getString("ip"), object.getInt("prefix_len"),
                    object.getString("gateway"), object.getString("broadcast"));
        } catch (VntException error) {
            throw error;
        } catch (Exception error) {
            throw new VntException("无法解析注册结果", error);
        }
    }

    public String getIp() { return ip; }
    public int getPrefixLen() { return prefixLen; }
    public String getGateway() { return gateway; }
    public String getBroadcast() { return broadcast; }
    public String toCidr() { return ip + "/" + prefixLen; }
}

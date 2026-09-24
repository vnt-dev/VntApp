package com.vnt;

import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 当前网络信息（网段）。
 *
 * createNetwork 时底层已在后台连接服务器并注册：网络已配置则立即返回，
 * 否则等待注册结果。注意：如果能创建此对象，说明获取网络一定成功了（失败会抛异常）
 */
public final class NetworkResult {

    private final String ip;
    private final int prefixLen;
    private final String gateway;
    private final String broadcast;
    private final List<String> routes;

    private NetworkResult(String ip, int prefixLen, String gateway, String broadcast,
                          List<String> routes) {
        this.ip = ip;
        this.prefixLen = prefixLen;
        this.gateway = gateway;
        this.broadcast = broadcast;
        this.routes = Collections.unmodifiableList(new ArrayList<>(routes));
    }

    static NetworkResult fromJson(String json) throws VntException {
        try {
            JSONObject obj = new JSONObject(json);
            if (!obj.getBoolean("success")) {
                throw new VntException(obj.optString("error", "注册被服务器拒绝"));
            }
            return fromObject(obj);
        } catch (VntException error) {
            throw error;
        } catch (Exception error) {
            throw new VntException("无法解析网络信息", error);
        }
    }

    private static NetworkResult fromObject(JSONObject obj) throws Exception {
        JSONArray values = obj.optJSONArray("routes");
        List<String> routes = new ArrayList<>();
        if (values != null) {
            for (int index = 0; index < values.length(); index++) {
                routes.add(values.getString(index));
            }
        }
        return new NetworkResult(
                obj.getString("ip"),
                obj.getInt("prefix_len"),
                obj.isNull("gateway") ? null : obj.getString("gateway"),
                obj.isNull("broadcast") ? null : obj.getString("broadcast"),
                routes
        );
    }

    public String getIp() { return ip; }
    public int getPrefixLen() { return prefixLen; }
    public String getGateway() { return gateway; }
    public String getBroadcast() { return broadcast; }

    /** 规范化后的入站路由（CIDR,下一跳 格式）。 */
    public List<String> getRoutes() { return routes; }

    public String toCidr() { return ip + "/" + prefixLen; }
}

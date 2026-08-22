package com.vnt;

import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;

public final class VntApi {
    private final long handle;
    VntApi(long handle) { this.handle = handle; }

    public List<ClientInfo> getClientList() throws VntException {
        try {
            JSONArray array = new JSONArray(nativeGetClientList(handle));
            List<ClientInfo> result = new ArrayList<>();
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.getJSONObject(i);
                String ip = item.getString("ip");
                result.add(new ClientInfo(ip, item.getBoolean("online"), isDirect(ip),
                        packetLoss(ip), traffic(ip)));
            }
            return result;
        } catch (Exception error) { throw wrap("读取设备列表", error); }
    }

    public NetworkInfo getNetwork() throws VntException {
        try {
            String raw = nativeGetNetwork(handle);
            if ("null".equals(raw)) return null;
            JSONObject item = new JSONObject(raw);
            return new NetworkInfo(item.getString("ip"), item.getInt("prefix_len"),
                    item.getString("gateway"), item.getString("broadcast"));
        } catch (Exception error) { throw wrap("读取网络信息", error); }
    }

    public NatInfo getNatInfo() throws VntException {
        try {
            String raw = nativeGetNatInfo(handle);
            if ("null".equals(raw)) return null;
            JSONObject item = new JSONObject(raw);
            List<String> ips = new ArrayList<>();
            JSONArray array = item.getJSONArray("public_ips");
            for (int i = 0; i < array.length(); i++) ips.add(array.getString(i));
            return new NatInfo(item.getString("nat_type"), ips,
                    item.isNull("ipv6") ? null : item.getString("ipv6"));
        } catch (Exception error) { throw wrap("读取 NAT 信息", error); }
    }

    public List<ServerInfo> getServerList() throws VntException {
        try {
            JSONArray array = new JSONArray(nativeGetServerList(handle));
            List<ServerInfo> result = new ArrayList<>();
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.getJSONObject(i);
                result.add(new ServerInfo(item.getString("server_addr"), item.getBoolean("connected"),
                        item.isNull("rtt") ? null : item.getInt("rtt"),
                        item.isNull("server_version") ? null : item.getString("server_version")));
            }
            return result;
        } catch (Exception error) { throw wrap("读取服务器列表", error); }
    }

    public List<RouteInfo> getRouteTable() throws VntException {
        try {
            JSONArray array = new JSONArray(nativeGetRouteTable(handle));
            List<RouteInfo> result = new ArrayList<>();
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.getJSONObject(i);
                JSONArray routeArray = item.getJSONArray("routes");
                List<RouteDetail> routes = new ArrayList<>();
                for (int j = 0; j < routeArray.length(); j++) {
                    JSONObject route = routeArray.getJSONObject(j);
                    routes.add(new RouteDetail(route.getString("route_key"), route.getString("protocol"),
                            route.getInt("metric"), route.getInt("rtt")));
                }
                result.add(new RouteInfo(item.getString("ip"), routes));
            }
            return result;
        } catch (Exception error) { throw wrap("读取路由表", error); }
    }

    public boolean isDirect(String ip) { return nativeIsDirect(handle, ip); }

    private PacketLoss packetLoss(String ip) {
        try {
            String raw = nativeGetPacketLoss(handle, ip);
            if ("null".equals(raw)) return null;
            JSONObject item = new JSONObject(raw);
            return new PacketLoss(item.getLong("sent"), item.getLong("received"), item.getDouble("loss_rate"));
        } catch (Exception ignored) { return null; }
    }

    private Traffic traffic(String ip) {
        try {
            String raw = nativeGetTrafficInfo(handle, ip);
            if ("null".equals(raw)) return null;
            JSONObject item = new JSONObject(raw);
            return new Traffic(item.getLong("tx_bytes"), item.getLong("rx_bytes"));
        } catch (Exception ignored) { return null; }
    }

    private static VntException wrap(String action, Exception error) {
        return error instanceof VntException ? (VntException) error : new VntException(action + "失败", error);
    }

    private static native String nativeGetClientList(long handle);
    private static native String nativeGetNetwork(long handle);
    private static native String nativeGetNatInfo(long handle);
    private static native String nativeGetServerList(long handle);
    private static native String nativeGetRouteTable(long handle);
    private static native boolean nativeIsDirect(long handle, String ip);
    private static native String nativeGetPacketLoss(long handle, String ip);
    private static native String nativeGetTrafficInfo(long handle, String ip);

    public record NetworkInfo(String ip, int prefixLen, String gateway, String broadcast) {}
    public record NatInfo(String type, List<String> publicIps, String ipv6) {}
    public record ServerInfo(String address, boolean connected, Integer rtt, String version) {}
    public record PacketLoss(long sent, long received, double rate) {}
    public record Traffic(long txBytes, long rxBytes) {}
    public record ClientInfo(String ip, boolean online, boolean direct, PacketLoss loss, Traffic traffic) {}
    public record RouteDetail(String key, String protocol, int metric, int rtt) {}
    public record RouteInfo(String ip, List<RouteDetail> routes) {}
}

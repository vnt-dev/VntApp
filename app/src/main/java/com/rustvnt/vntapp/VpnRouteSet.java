package com.rustvnt.vntapp;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

final class VpnRouteSet {
    record Route(String address, int prefix) {
        String cidr() { return address + "/" + prefix; }
    }

    private VpnRouteSet() {}

    static List<Route> build(String ip, int prefixLen, List<String> outputRoutes,
                             List<String> inputRoutes, List<String> syncedRoutes) {
        LinkedHashMap<String, Route> routes = new LinkedHashMap<>();
        add(routes, ip + "/" + prefixLen);
        for (String route : outputRoutes) add(routes, route);
        for (String route : inputRoutes) add(routes, route);
        for (String route : syncedRoutes) add(routes, route);
        return new ArrayList<>(routes.values());
    }

    static Set<String> cidrs(List<String> routes) {
        Set<String> result = new LinkedHashSet<>();
        for (String route : routes) result.add(parse(route).cidr());
        return result;
    }

    private static void add(LinkedHashMap<String, Route> routes, String value) {
        Route route = parse(value);
        routes.putIfAbsent(route.cidr(), route);
    }

    private static Route parse(String value) {
        String cidr = value == null ? "" : value.split(",", 2)[0].trim();
        String[] parts = cidr.split("/", -1);
        if (parts.length != 2) throw new IllegalArgumentException("无效路由：" + value);
        int prefix;
        try {
            prefix = Integer.parseInt(parts[1]);
        } catch (NumberFormatException error) {
            throw new IllegalArgumentException("无效路由前缀：" + value, error);
        }
        if (prefix < 0 || prefix > 32) throw new IllegalArgumentException("无效路由前缀：" + value);
        int address = parseIpv4(parts[0].trim(), value);
        int mask = prefix == 0 ? 0 : -1 << (32 - prefix);
        int network = address & mask;
        String normalized = ((network >>> 24) & 255) + "." + ((network >>> 16) & 255) + "." +
                ((network >>> 8) & 255) + "." + (network & 255);
        return new Route(normalized, prefix);
    }

    private static int parseIpv4(String address, String original) {
        String[] octets = address.split("\\.", -1);
        if (octets.length != 4) throw new IllegalArgumentException("无效 IPv4 路由：" + original);
        int value = 0;
        for (String octet : octets) {
            int parsed;
            try {
                parsed = Integer.parseInt(octet);
            } catch (NumberFormatException error) {
                throw new IllegalArgumentException("无效 IPv4 路由：" + original, error);
            }
            if (parsed < 0 || parsed > 255) {
                throw new IllegalArgumentException("无效 IPv4 路由：" + original);
            }
            value = (value << 8) | parsed;
        }
        return value;
    }
}

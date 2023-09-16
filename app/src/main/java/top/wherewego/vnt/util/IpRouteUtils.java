package top.wherewego.vnt.util;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.List;

public class IpRouteUtils {
    public static class RouteItem {
        public InetAddress address;
        public int prefixLength;

        public RouteItem(InetAddress address, int prefixLength) {
            this.address = address;
            this.prefixLength = prefixLength;
        }
    }

    public static List<RouteItem> inIp(String inIps) {
        if (inIps == null || inIps.isEmpty()) {
            return new ArrayList<>();
        }
        List<RouteItem> list = new ArrayList<>();
        for (String s : inIps.split("\n")) {
            String s1 = s.split(",")[0];
            String[] split = s1.split("/");
            InetAddress address;
            try {
                address = InetAddress.getByName(split[0]);
            } catch (UnknownHostException e) {
                throw new RuntimeException(e);
            }
            int prefixLengt = Integer.parseInt(split[1]);
            list.add(new RouteItem(address, prefixLengt));
        }
        return list;
    }

    public static String checkInIps(String inIps) {
        if (inIps == null || inIps.isEmpty()) {
            return null;
        }
        for (String s : inIps.split("\n")) {
            String[] split = s.split(",");
            if (split.length != 2) {
                return "not ipv4/mask,ipv4";
            }
            try {
                InetAddress.getByName(split[1]);
            } catch (Exception e) {
                return "not ipv4";
            }
            String s1 = s.split(",")[0];
            String[] split1 = s1.split("/");
            try {
                InetAddress.getByName(split1[0]);
            } catch (Exception e) {
                return "not ipv4";
            }
            try {
                int mask = Integer.parseInt(split1[1]);
                if (mask >= 32 || mask < 0) {
                    return "mask >= 32 || mask < 0";
                }
            } catch (Exception e) {
                return "no netmask";
            }
        }
        return null;
    }

    public static String checkOutIps(String outIps) {
        if (outIps == null || outIps.isEmpty()) {
            return null;
        }
        for (String s : outIps.split("\n")) {
            String[] split1 = s.split("/");
            try {
                InetAddress.getByName(split1[0]);
            } catch (Exception e) {
                return "not ipv4";
            }
            try {
                int mask = Integer.parseInt(split1[1]);
                if (mask >= 32 || mask < 0) {
                    return "mask >= 32 || mask < 0";
                }
            } catch (Exception e) {
                return "no netmask";
            }
        }
        return null;
    }
}

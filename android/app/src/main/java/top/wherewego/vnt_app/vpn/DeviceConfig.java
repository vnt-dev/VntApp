package top.wherewego.vnt_app.vpn;

import java.util.List;

/**
 * 启动VPN的配置
 *
 * @author https://github.com/lbl8603/vnt
 */
public class DeviceConfig {
    public int virtualIp;
    public int virtualNetmask;
    public int virtualGateway;
    public int mtu;
    public List<Route> externalRoute;

    public DeviceConfig(int virtualIp, int virtualNetmask, int virtualGateway, int mtu, List<Route> externalRoute) {
        this.virtualIp = virtualIp;
        this.virtualNetmask = virtualNetmask;
        this.virtualGateway = virtualGateway;
        this.mtu = mtu;
        this.externalRoute = externalRoute;
    }

    public static class Route {
        public int destination;
        public int netmask;

        public Route(int destination, int netmask) {
            this.destination = destination;
            this.netmask = netmask;
        }

        @Override
        public String toString() {
            return "Route{" +
                    "destination=" + destination +
                    ", netmask=" + netmask +
                    '}';
        }
    }

    @Override
    public String toString() {
        return "DeviceConfig{" +
                "virtualIp=" + virtualIp +
                ", virtualNetmask=" + virtualNetmask +
                ", virtualGateway=" + virtualGateway +
                ", mtu=" + mtu +
                ", externalRoute=" + externalRoute +
                '}';
    }
}



package top.wherewego.vnt.jni;

public class RegResponse {
    private final int virtualIp;
    private final int virtualGateway;
    private final int virtualNetmask;

    public RegResponse(int virtualIp, int virtualGateway, int virtualNetmask) {
        this.virtualIp = virtualIp;
        this.virtualGateway = virtualGateway;
        this.virtualNetmask = virtualNetmask;
    }

    public int getVirtualIp() {
        return virtualIp;
    }

    public int getVirtualGateway() {
        return virtualGateway;
    }

    public int getVirtualNetmask() {
        return virtualNetmask;
    }

    @Override
    public String toString() {
        return "RegResponse{" +
                "virtualIp=" + virtualIp +
                ", virtualGateway=" + virtualGateway +
                ", virtualNetmask=" + virtualNetmask +
                '}';
    }
}

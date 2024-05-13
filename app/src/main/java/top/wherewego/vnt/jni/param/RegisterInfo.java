package top.wherewego.vnt.jni.param;

import top.wherewego.vnt.jni.IpUtils;

/**
 * 注册回调信息
 *
 * @author https://github.com/lbl8603/vnt
 */
public class RegisterInfo {
    /**
     * 虚拟IP
     */
    public final int virtualIp;
    /**
     * 掩码
     */
    public final int virtualNetmask;
    /**
     * 网关
     */
    public final int virtualGateway;

    public RegisterInfo(int virtualIp, int virtualNetmask, int virtualGateway) {
        this.virtualIp = virtualIp;
        this.virtualNetmask = virtualNetmask;
        this.virtualGateway = virtualGateway;
    }

    public int getVirtualIp() {
        return virtualIp;
    }

    public int getVirtualNetmask() {
        return virtualNetmask;
    }

    public int getVirtualGateway() {
        return virtualGateway;
    }

    @Override
    public String toString() {
        return "RegisterInfo{" +
                "virtualIp='" + IpUtils.intToIpAddress(virtualIp) + '\'' +
                ", virtualNetmask='" + IpUtils.intToIpAddress(virtualNetmask) + '\'' +
                ", virtualGateway='" + IpUtils.intToIpAddress(virtualGateway) + '\'' +
                '}';
    }
}

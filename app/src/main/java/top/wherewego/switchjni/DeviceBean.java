package top.wherewego.switchjni;

public class DeviceBean implements Comparable<DeviceBean> {
    private String name;
    private String ip;
    private String status;
    private String rt;
    private String connectType;

    public DeviceBean(String name, String ip, String status, String rt, String connectType) {
        this.name = name;
        this.ip = ip;
        this.status = status;
        this.rt = rt;
        this.connectType = connectType;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getRt() {
        return rt;
    }

    public void setRt(String rt) {
        this.rt = rt;
    }

    public String getConnectType() {
        return connectType;
    }

    public void setConnectType(String connectType) {
        this.connectType = connectType;
    }

    @Override
    public int compareTo(DeviceBean deviceBean) {
        int c = deviceBean.status.compareTo(this.status);
        if (c == 0) {
            c = this.ip.compareTo(deviceBean.ip);
        }
        return c;
    }
}

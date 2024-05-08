package top.wherewego.vnt.jni;

import java.io.Serializable;

public class ConfigurationInfoBean implements Serializable {
    private String key;
    private String token;
    private String name;
    private String deviceId;
    private String password;
    private String server;
    private String stun;
    private String cipherModel;
    private boolean tcp;
    private boolean finger;
    private String inIps;
    private String outIps;
    private boolean firstLatency;
    private int port;

    public ConfigurationInfoBean(String token, String name, String deviceId, String password,
                                 String server, String stun, String cipherModel, boolean tcp, boolean finger,
                                 String inIps, String outIps,boolean firstLatency,int port) {
        this.key = String.valueOf(System.currentTimeMillis());
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.password = password;
        this.server = server;
        this.stun = stun;
        this.cipherModel = cipherModel;
        this.tcp = tcp;
        this.finger = finger;
        this.inIps = inIps;
        this.outIps = outIps;
        this.firstLatency = firstLatency;
        this.port = port;
    }

    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getServer() {
        return server;
    }

    public void setServer(String server) {
        this.server = server;
    }

    public String getStun() {
        return stun;
    }

    public void setStun(String stun) {
        this.stun = stun;
    }

    public String getCipherModel() {
        return cipherModel;
    }

    public void setCipherModel(String cipherModel) {
        this.cipherModel = cipherModel;
    }

    public boolean isTcp() {
        return tcp;
    }

    public void setTcp(boolean tcp) {
        this.tcp = tcp;
    }

    public boolean isFinger() {
        return finger;
    }

    public void setFinger(boolean finger) {
        this.finger = finger;
    }

    public String getInIps() {
        return inIps;
    }

    public void setInIps(String inIps) {
        this.inIps = inIps;
    }

    public String getOutIps() {
        return outIps;
    }

    public void setOutIps(String outIps) {
        this.outIps = outIps;
    }

    public boolean isFirstLatency() {
        return firstLatency;
    }

    public void setFirstLatency(boolean firstLatency) {
        this.firstLatency = firstLatency;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }
}

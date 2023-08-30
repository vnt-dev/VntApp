package top.wherewego.vnt.jni;

import java.io.Serializable;

public class ConfigurationInfoBean implements Serializable {
    private final String key;
    private String token;
    private String name;
    private String deviceId;
    private String password;
    private String server;
    private String stun;
    private String cipherModel;
    private boolean isTcp;

    public ConfigurationInfoBean(String token, String name, String deviceId, String password, String server, String stun,String cipherModel,boolean isTcp) {
        this.key = String.valueOf(System.currentTimeMillis());
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.password = password;
        this.server = server;
        this.stun = stun;
        this.cipherModel = cipherModel;
        this.isTcp = isTcp;
    }

    public String getKey() {
        return key;
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
        return isTcp;
    }

    public void setTcp(boolean tcp) {
        isTcp = tcp;
    }
}

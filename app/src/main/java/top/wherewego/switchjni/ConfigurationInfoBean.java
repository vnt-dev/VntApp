package top.wherewego.switchjni;

import java.io.Serializable;

public class ConfigurationInfoBean implements Serializable {
    private final String key;
    private String token;
    private String name;
    private String deviceId;
    private String password;
    private String server;
    private String serverAddress;

    public ConfigurationInfoBean(String token, String name, String deviceId, String password, String server, String serverAddress) {
        this.key = String.valueOf(System.currentTimeMillis());
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.password = password;
        this.server = server;
        this.serverAddress = serverAddress;
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

    public String getServerAddress() {
        return serverAddress;
    }

    public void setServerAddress(String serverAddress) {
        this.serverAddress = serverAddress;
    }
}

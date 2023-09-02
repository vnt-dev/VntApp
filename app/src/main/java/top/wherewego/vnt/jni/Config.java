package top.wherewego.vnt.jni;

public class Config {
    private String token;
    private String name;
    private String deviceId;
    private String server;
    private String stunServer;
    private String password;
    private String cipherModel;
    private boolean tcp;
    private boolean finger;


    public Config(String token, String name, String deviceId, String server, String stunServer, String password, String cipherModel, boolean tcp,boolean finger) {
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.server = server;
        this.stunServer = stunServer;
        this.password = password;
        this.cipherModel = cipherModel;
        this.tcp = tcp;
        this.finger = finger;
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

    public String getServer() {
        return server;
    }

    public void setServer(String server) {
        this.server = server;
    }

    public String getStunServer() {
        return stunServer;
    }

    public void setStunServer(String stunServer) {
        this.stunServer = stunServer;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
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
}

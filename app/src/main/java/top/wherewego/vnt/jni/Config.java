package top.wherewego.vnt.jni;

public class Config {
    private String token;
    private String name;
    private String deviceId;
    private String server;
    private String stunServer;
    private String password;
    private String cipherModel;
    private boolean isTcp;


    public Config(String token, String name, String deviceId, String server, String stunServer, String password, String cipherModel, boolean isTcp) {
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.server = server;
        this.stunServer = stunServer;
        this.password = password;
        this.cipherModel = cipherModel;
        this.isTcp = isTcp;
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
        return isTcp;
    }

    public void setTcp(boolean tcp) {
        isTcp = tcp;
    }
}

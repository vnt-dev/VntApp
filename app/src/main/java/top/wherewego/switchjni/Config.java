package top.wherewego.switchjni;

public class Config {
    private String token;
    private String name;
    private String deviceId;
    private String server;
    private String natTestServer;
    private String password;


    public Config(String token, String name, String deviceId, String server, String natTestServer, String password) {
        this.token = token;
        this.name = name;
        this.deviceId = deviceId;
        this.server = server;
        this.natTestServer = natTestServer;
        this.password = password;
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

    public String getNatTestServer() {
        return natTestServer;
    }

    public void setNatTestServer(String natTestServer) {
        this.natTestServer = natTestServer;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}

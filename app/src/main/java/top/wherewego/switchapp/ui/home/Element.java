package top.wherewego.switchapp.ui.home;

public class Element {
    private String id;
    private String serverAddress;
    private String token;
    private String name;

    public Element(String id, String serverAddress, String token, String name) {
        this.id = id;
        this.serverAddress = serverAddress;
        this.token = token;
        this.name = name;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getServerAddress() {
        return serverAddress;
    }

    public void setServerAddress(String serverAddress) {
        this.serverAddress = serverAddress;
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
}

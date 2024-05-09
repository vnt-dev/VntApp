package top.wherewego.vnt.config;

import java.io.Serializable;

import top.wherewego.vnt.jni.Config;

public class ConfigurationInfoBean extends Config implements Serializable {
    private String key;
    private String vpnName;

    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    public String getVpnName() {
        return vpnName;
    }

    public void setVpnName(String vpnName) {
        this.vpnName = vpnName;
    }

    @Override
    public String toString() {
        return "ConfigurationInfoBean{" +
                "key='" + key + '\'' +
                "config"+super.toString()+
                '}';
    }
}

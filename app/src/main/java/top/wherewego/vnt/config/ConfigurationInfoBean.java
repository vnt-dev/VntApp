package top.wherewego.vnt.config;

import java.io.Serializable;

import top.wherewego.vnt.jni.Config;

public class ConfigurationInfoBean extends Config implements Serializable {
    private String key;

    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    @Override
    public String toString() {
        return "ConfigurationInfoBean{" +
                "key='" + key + '\'' +
                "config"+super.toString()+
                '}';
    }
}

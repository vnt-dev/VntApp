package com.vnt;

public final class VntManager {
    static { System.loadLibrary("vnt_jni"); }

    private VntManager() {}

    public static boolean init() { return nativeInit(); }
    public static void destroy() { nativeDestroy(); }

    /** Fetches and mutually authenticates the latest configuration for a subscription. */
    public static String fetchSubscriptionConfig(String subscription) throws VntException {
        try {
            return nativeFetchSubscriptionConfig(subscription);
        } catch (Exception error) {
            throw new VntException("获取订阅配置失败", error);
        }
    }

    /** Passes the persisted JSON configuration to the Rust core without translation. */
    public static VntNetwork createNetwork(String configJson) {
        long handle = nativeCreateNetwork(configJson);
        return handle < 0 ? null : new VntNetwork(handle);
    }

    private static native boolean nativeInit();
    private static native void nativeDestroy();
    private static native String nativeFetchSubscriptionConfig(String subscription);
    private static native long nativeCreateNetwork(String configJson);
}

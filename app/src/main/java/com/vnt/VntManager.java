package com.vnt;

public final class VntManager {
    static { System.loadLibrary("vnt_jni"); }

    private VntManager() {}

    public static boolean init() { return nativeInit(); }
    public static void destroy() { nativeDestroy(); }

    /** Passes the persisted JSON configuration to the Rust core without translation. */
    public static VntNetwork createNetwork(String configJson) {
        return createNetwork(configJson, null);
    }

    public static VntNetwork createNetwork(String configJson, VntNetwork.IpUpdateListener listener) {
        long handle = nativeCreateNetwork(configJson, listener);
        return handle < 0 ? null : new VntNetwork(handle);
    }

    private static native boolean nativeInit();
    private static native void nativeDestroy();
    private static native long nativeCreateNetwork(String configJson, VntNetwork.IpUpdateListener listener);
}

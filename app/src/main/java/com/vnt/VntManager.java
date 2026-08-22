package com.vnt;

public final class VntManager {
    static { System.loadLibrary("vnt_jni"); }

    private VntManager() {}

    public static boolean init() { return nativeInit(); }
    public static void destroy() { nativeDestroy(); }

    /** Passes the persisted JSON configuration to the Rust core without translation. */
    public static VntNetwork createNetwork(String configJson) {
        long handle = nativeCreateNetwork(configJson);
        return handle < 0 ? null : new VntNetwork(handle);
    }

    private static native boolean nativeInit();
    private static native void nativeDestroy();
    private static native long nativeCreateNetwork(String configJson);
}

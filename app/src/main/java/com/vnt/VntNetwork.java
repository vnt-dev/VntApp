package com.vnt;

public final class VntNetwork {
    public interface IpUpdateListener {
        void onIpUpdate(long requestId, String ip, int prefixLen);
    }

    private final long nativeHandle;
    private boolean closed;

    VntNetwork(long nativeHandle) { this.nativeHandle = nativeHandle; }

    public synchronized RegisterResult register() throws VntException {
        checkOpen();
        return RegisterResult.fromJson(nativeRegister(nativeHandle));
    }

    public synchronized void startTun(int fd) throws VntException {
        checkOpen();
        if (!nativeStartTun(nativeHandle, fd)) throw new VntException("Rust 核心无法启动 TUN");
    }

    public synchronized void prepareIpUpdate(long requestId, String ip) throws VntException {
        checkOpen();
        if (!nativePrepareIpUpdate(nativeHandle, requestId, ip)) {
            throw new VntException("Rust 核心无法暂停旧 TUN");
        }
    }

    /** Native always takes ownership of a non-negative fd, including failure paths. */
    public synchronized void completeIpUpdate(long requestId, String ip, int fd) throws VntException {
        checkOpen();
        if (!nativeCompleteIpUpdate(nativeHandle, requestId, ip, fd)) {
            throw new VntException("Rust 核心无法启动新 TUN");
        }
    }

    public synchronized VntApi getApi() throws VntException {
        checkOpen();
        long apiHandle = nativeGetApi(nativeHandle);
        if (apiHandle < 0) throw new VntException("无法获取 VNT 状态接口");
        return new VntApi(apiHandle);
    }

    public synchronized boolean isNoTun() { checkOpen(); return nativeIsNoTun(nativeHandle); }

    public synchronized void stop() {
        if (!closed) {
            nativeStop(nativeHandle);
            closed = true;
        }
    }

    private void checkOpen() {
        if (closed) throw new IllegalStateException("VNT 实例已经关闭");
    }

    private static native String nativeRegister(long handle);
    private static native boolean nativeStartTun(long handle, int tunFd);
    private static native boolean nativePrepareIpUpdate(long handle, long requestId, String ip);
    private static native boolean nativeCompleteIpUpdate(long handle, long requestId, String ip, int tunFd);
    private static native long nativeGetApi(long handle);
    private static native boolean nativeIsNoTun(long handle);
    private static native boolean nativeStop(long handle);
}

package com.vnt;

/** A running VNT network instance backed by the native runtime. */
public final class VntNetwork {
    private final long nativeHandle;
    private volatile boolean closed;
    private Thread tunRebuildThread;

    VntNetwork(long nativeHandle) { this.nativeHandle = nativeHandle; }

    public synchronized RegisterResult register() throws VntException {
        checkOpen();
        return RegisterResult.fromJson(nativeRegister(nativeHandle));
    }

    /** Ownership of a non-negative fd transfers to Rust, including failure paths. */
    public synchronized void startTun(int fd) throws VntException {
        checkOpen();
        if (!nativeStartTun(nativeHandle, fd)) throw new VntException("Rust 核心无法启动 TUN");
    }

    /** Blocks until Rust requests a replacement Android VPN, or the instance stops. */
    public TunRebuildRequest waitTunRebuild() throws VntException {
        checkOpen();
        String request = nativeWaitTunRebuild(nativeHandle);
        return request == null ? null : TunRebuildRequest.fromJson(request);
    }

    /** Ownership of the detached fd transfers to Rust, including failure paths. */
    public void replaceTun(long requestId, int fd) throws VntException {
        checkOpen();
        if (!nativeReplaceTun(nativeHandle, requestId, fd)) {
            throw new VntException("Rust 核心无法替换 TUN 任务");
        }
    }

    /** Rejects a pending replacement while preserving the Rust-owned old TUN. */
    public void rejectTunRebuild(long requestId, String reason) throws VntException {
        checkOpen();
        if (!nativeRejectTunRebuild(nativeHandle, requestId, reason)) {
            throw new VntException("Rust 核心无法取消 TUN 重建");
        }
    }

    /** Java owns this blocking listener; Rust never calls Java. */
    public synchronized void listenTunRebuild(TunRebuildListener listener) {
        checkOpen();
        if (tunRebuildThread != null) throw new IllegalStateException("TUN 重建监听已启动");
        tunRebuildThread = new Thread(() -> {
            while (!closed) {
                try {
                    TunRebuildRequest request = waitTunRebuild();
                    if (request == null) break;
                    try {
                        listener.onTunRebuildRequired(request);
                    } catch (Exception error) {
                        if (!closed) {
                            try { rejectTunRebuild(request.getRequestId(), error.toString()); }
                            catch (Exception rejectError) { error.addSuppressed(rejectError); }
                        }
                    }
                } catch (IllegalStateException ignored) {
                    break;
                } catch (Exception error) {
                    if (!closed) error.printStackTrace();
                }
            }
        }, "vnt-tun-rebuild-listener");
        tunRebuildThread.setDaemon(true);
        tunRebuildThread.start();
    }

    public synchronized VntApi getApi() throws VntException {
        checkOpen();
        long apiHandle = nativeGetApi(nativeHandle);
        if (apiHandle < 0) throw new VntException("无法获取 VNT 状态接口");
        return new VntApi(apiHandle);
    }

    public synchronized boolean isNoTun() { checkOpen(); return nativeIsNoTun(nativeHandle); }

    public synchronized void stop() {
        if (closed) return;
        nativeStop(nativeHandle);
        closed = true;
    }

    private void checkOpen() {
        if (closed) throw new IllegalStateException("VNT 实例已经关闭");
    }

    private static native String nativeRegister(long handle);
    private static native boolean nativeStartTun(long handle, int tunFd);
    private static native String nativeWaitTunRebuild(long handle);
    private static native boolean nativeReplaceTun(long handle, long requestId, int tunFd);
    private static native boolean nativeRejectTunRebuild(long handle, long requestId, String reason);
    private static native long nativeGetApi(long handle);
    private static native boolean nativeIsNoTun(long handle);
    private static native boolean nativeStop(long handle);
}

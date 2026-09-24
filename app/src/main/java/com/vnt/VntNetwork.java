package com.vnt;

import java.util.ArrayList;
import java.util.List;
import org.json.JSONArray;

/** A running VNT network instance backed by the native runtime. */
public final class VntNetwork {
    private final long nativeHandle;
    private volatile boolean closed;

    VntNetwork(long nativeHandle) { this.nativeHandle = nativeHandle; }

    /**
     * 获取当前网络（网段信息）。createNetwork 时底层已在后台连接服务器并注册：
     * 网络已配置则立即返回，否则等待注册结果。
     */
    public synchronized NetworkResult getNetwork() throws VntException {
        checkOpen();
        return NetworkResult.fromJson(nativeGetNetwork(nativeHandle));
    }

    /** 实例最近日志（每个实例保留最后 50 条，按时间正序）。 */
    public synchronized List<LogEntry> getLogs() throws VntException {
        checkOpen();
        try {
            JSONArray array = new JSONArray(nativeGetLogs(nativeHandle));
            List<LogEntry> logs = new ArrayList<>();
            for (int i = 0; i < array.length(); i++) {
                logs.add(LogEntry.fromJson(array.getJSONObject(i)));
            }
            return logs;
        } catch (Exception error) {
            throw new VntException("无法解析实例日志", error);
        }
    }

    /** Ownership of a non-negative fd transfers to Rust, including failure paths. */
    public synchronized void startTun(int fd) throws VntException {
        checkOpen();
        if (!nativeStartTun(nativeHandle, fd)) throw new VntException("Rust 核心无法启动 TUN");
    }

    /**
     * 阻塞等待下一次运行期事件：组网实例停止或新的完整快照。收到
     * instance_stopped 时应结束变更循环，收到 changed 时快照由
     * {@link #applyRuntimeChange()} / {@link #applyRuntimeChange(int)} 消费。
     */
    public RuntimeEvent nextEvent() throws VntException {
        checkOpen();
        return RuntimeEvent.fromJson(nativeNextEvent(nativeHandle));
    }

    /**
     * 应用 nextEvent 返回的最新快照（不携带 TUN fd）：纯策略/服务器类变更
     * 原地生效。快照的 {@link RuntimeChange#isVpnRebuild()} /
     * {@link RuntimeChange#isInstanceRebuild()} 为 true 时应改用
     * {@link #applyRuntimeChange(int)} 携带新建接口的 fd。
     */
    public ChangeApplyResult applyRuntimeChange() throws VntException {
        checkOpen();
        return ChangeApplyResult.fromJson(nativeApplyRuntimeChange(nativeHandle));
    }

    /**
     * 应用 nextEvent 返回的最新快照，携带宿主新建的 TUN fd：网卡相关信息
     * 变化或需要重建组网实例时使用。Ownership of the detached fd transfers to
     * Rust, including failure paths.
     */
    public ChangeApplyResult applyRuntimeChange(int fd) throws VntException {
        checkOpen();
        return ChangeApplyResult.fromJson(nativeApplyRuntimeChangeFd(nativeHandle, fd));
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

    private static native String nativeGetNetwork(long handle);
    private static native String nativeGetLogs(long handle);
    private static native boolean nativeStartTun(long handle, int tunFd);
    private static native String nativeNextEvent(long handle);
    private static native String nativeApplyRuntimeChange(long handle);
    private static native String nativeApplyRuntimeChangeFd(long handle, int tunFd);
    private static native long nativeGetApi(long handle);
    private static native boolean nativeIsNoTun(long handle);
    private static native boolean nativeStop(long handle);
}
